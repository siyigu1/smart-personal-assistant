"""Personal Assistant Daemon — main entry point.

Lightweight Python daemon that handles deterministic work (polling,
reminders, scheduling) and invokes the LLM only when intelligence
is needed.
"""

import os
import sys
import time
import signal
import argparse
from datetime import datetime
from typing import Optional

from .config import load_config, Config
from .channels.slack import SlackChannel
from .llm.claude_cli import ClaudeCLI
from .llm.base import LLMBridge
from .reminder_engine import ReminderEngine
from .cross_tasks import CrossTaskChecker
from .automations import check_and_run as check_automations
from .context_builder import build_prompt
from .file_updater import apply_updates
from .activity_log import ActivityLog
from .conversation import Conversation


def needs_onboarding(config: Config) -> bool:
    """Check if the user needs onboarding (first run).

    Returns True if the Workstreams.md file still contains the
    onboarding placeholder text, meaning the AI hasn't interviewed
    the user yet.
    """
    ws_path = os.path.join(config.notes_folder, "Workstreams.md")
    if not os.path.exists(ws_path):
        return True
    with open(ws_path) as f:
        content = f.read()
    markers = [
        "Not filled in yet",      # English template
        "set during onboarding",  # English template
        "尚未填写",                # Chinese template
        "入门设置时填写",           # Chinese template
        "{{WORKSTREAM_SECTIONS}}", # Raw template placeholder (never substituted)
        "（在这里添加想法）",        # Chinese empty template
        "_(Add ideas here",       # English empty template
    ]
    return any(m in content for m in markers)


def create_channel(config: Config):
    """Create the appropriate channel client based on config."""
    if config.channel_provider == "slack":
        state_file = os.path.join(config.notes_folder, ".mc-state.json")
        return SlackChannel(
            bot_token=config.slack_bot_token,
            channel_id=config.slack_channel_id,
            state_file=state_file,
        )
    else:
        raise ValueError(f"Unknown channel provider: {config.channel_provider}")


def create_llm(config: Config, channel) -> LLMBridge:
    """Create the appropriate LLM bridge based on config.

    The channel is passed so the LLM bridge can notify the user
    via Slack when errors occur (e.g., 401 auth required).
    """
    if config.llm_provider == "claude-cli":
        return ClaudeCLI(timeout=180, on_error=_llm_error_notifier(channel, config))
    else:
        raise ValueError(f"Unknown LLM provider: {config.llm_provider}")


# Tracks which error types have been notified to avoid spamming Slack
_notified_errors: set = set()


_ERROR_MESSAGES = {
    "en": {
        "auth_required": "Claude CLI needs you to log in again. Go to your computer and run: claude login",
        "update_required": "Claude CLI has an update available. Go to your computer and run: claude update",
        "prefix": "Action needed",
    },
    "zh": {
        "auth_required": "Claude CLI 需要你重新登录。请到电脑上运行：claude login",
        "update_required": "Claude CLI 有更新。请到电脑上运行：claude update",
        "prefix": "需要你操作",
    },
}


def _llm_error_notifier(channel, config):
    """Create an error callback that notifies Slack once per error type."""
    def on_error(error_type, message_key):
        if error_type.value in _notified_errors:
            return
        _notified_errors.add(error_type.value)
        lang = config.language if config.language in _ERROR_MESSAGES else "en"
        msgs = _ERROR_MESSAGES[lang]
        prefix = msgs["prefix"]
        if message_key in msgs:
            detail = msgs[message_key]
        elif message_key.startswith("unknown:"):
            code = message_key.split(":")[1]
            detail = f"Claude CLI error (exit code {code})" if lang == "en" else f"Claude CLI 错误（退出码 {code}）"
        else:
            detail = message_key
        channel.post(f"⚠️ *{prefix}:* {detail}")
    return on_error


def notify_llm_failure(channel, operation: str, config=None, activity=None):
    """Notify user via Slack that an LLM call failed. Only once."""
    key = f"llm_failure_{operation}"
    if key in _notified_errors:
        return
    _notified_errors.add(key)
    if config and config.language == "zh":
        channel.post(
            f"⚠️ 尝试运行 *{operation}* 但没有收到 AI 的回复。"
            f"可能是临时问题——我会继续尝试。"
            f"如果持续出现，请运行 `./status.sh errors` 查看详情。"
        )
    else:
        channel.post(
            f"⚠️ I tried to run *{operation}* but didn't get a response from the AI. "
            f"This might be a temporary issue — I'll keep trying. "
            f"If it persists, check `./status.sh errors` for details."
        )
    if activity:
        activity.llm_error(operation, "Empty response from LLM")


def run_operation(
    llm: LLMBridge,
    channel,
    config: Config,
    operation: str,
    user_message: str = "",
    activity: Optional[ActivityLog] = None,
    conversation_history: str = "",
):
    """Run an LLM-powered operation and post results.

    This is the only function that invokes the LLM. Everything else
    in the daemon is pure code.
    """
    # Build Slack history context for operations that need it
    slack_history = ""
    if operation in ("midday_checkin", "afternoon_checkin", "eod_summary"):
        recent = channel.get_recent_history(limit=20)
        slack_history = "\n".join(
            f"{'[bot]' if m.is_bot else '[user]'}: {m.text}"
            for m in reversed(recent)
        )

    # Build the prompt with only relevant state files
    prompt = build_prompt(
        notes_folder=config.notes_folder,
        operation=operation,
        user_message=user_message,
        slack_history=slack_history,
        conversation_history=conversation_history,
    )

    # Invoke the LLM
    print(f"[daemon] Invoking LLM for: {operation}")
    t0 = time.time()
    raw_response = llm.invoke(prompt)
    duration = time.time() - t0

    if not raw_response:
        print(f"[daemon] Empty response from LLM for: {operation}")
        notify_llm_failure(channel, operation, config=config, activity=activity)
        return

    # Clear the failure flag for this operation on success
    _notified_errors.discard(f"llm_failure_{operation}")

    # Parse structured response
    response = llm.parse_response(raw_response)

    # Post to channel (strip internal markers)
    if response.slack_message:
        clean_msg = response.slack_message.replace("ONBOARDING_COMPLETE", "").strip()
        if clean_msg:
            channel.post(clean_msg)

    # Apply file updates
    if response.file_updates:
        updated = apply_updates(response, config.notes_folder)
        print(f"[daemon] Applied {updated} file update(s)")

    # Save short-term memory with timestamps for TTL
    if response.short_term_memory:
        import json as _json
        stm_path = os.path.join(config.notes_folder, ".short-term-memory.json")

        # Load existing, merge new entries with timestamps
        existing = {}
        if os.path.exists(stm_path):
            try:
                with open(stm_path) as f:
                    existing = _json.load(f)
            except (ValueError, OSError):
                pass

        now = time.time()
        for key, value in response.short_term_memory.items():
            existing[key] = {"value": value, "ts": now}

        # Prune entries older than 24 hours
        cutoff = now - 86400
        existing = {k: v for k, v in existing.items()
                    if isinstance(v, dict) and v.get("ts", 0) > cutoff}

        with open(stm_path, "w") as f:
            _json.dump(existing, f, indent=2, ensure_ascii=False)
        print(f"[daemon] Short-term memory: {len(existing)} entries")

    # Log the call
    if activity:
        activity.llm_call(
            operation=operation,
            prompt_tokens=len(prompt) // 4,  # rough estimate
            response_preview=response.slack_message[:200] if response.slack_message else "",
            duration_sec=duration,
        )


def main():
    parser = argparse.ArgumentParser(description="Personal Assistant Daemon")
    parser.add_argument(
        "--config", "-c",
        help="Path to .mc-config.json",
        default=None,
    )
    parser.add_argument(
        "--once",
        action="store_true",
        help="Run one cycle and exit (for testing)",
    )
    args = parser.parse_args()

    # Load configuration
    config = load_config(args.config)

    # Set up activity logging
    log_dir = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "logs")
    activity = ActivityLog(log_dir, ttl_days=7)

    print(f"[daemon] Personal Assistant for {config.user_name}")
    print(f"[daemon] Notes: {config.notes_folder}")
    print(f"[daemon] Channel: {config.channel_provider} ({config.slack_channel_name})")
    print(f"[daemon] LLM: {config.llm_provider}")

    # Create components
    channel = create_channel(config)
    llm = create_llm(config, channel)
    reminders = ReminderEngine(config.notes_folder)
    conversation = Conversation(config.notes_folder)

    activity.startup(config.user_name, config.notes_folder)

    # Clean up old logs on startup
    deleted = activity.cleanup_old_logs()
    if deleted > 0:
        print(f"[daemon] Cleaned up {deleted} old log file(s)")

    # Check if onboarding is needed (first run or resumed)
    if needs_onboarding(config) and not conversation.is_active():
        print("[daemon] New user detected — starting onboarding conversation")
        activity.log("onboarding", "New user detected, starting onboarding")
        conversation.start("onboarding")

        if config.language == "zh":
            welcome = (
                f"你好 {config.user_name}！我是{config.assistant_name}。"
                f"让我们来设置你的系统吧——我会问几个关于你的日程和项目的问题，大概 15 分钟。\n\n"
                f"准备好了吗？（回复'好'或'开始'就行）"
            )
        else:
            welcome = (
                f"Hi {config.user_name}! I'm {config.assistant_name}. "
                f"Let's set up your system — I'll ask a few questions about "
                f"your schedule and projects. Takes about 15 minutes.\n\n"
                f"Ready to get started? (just reply 'yes' or 'let's go')"
            )
        channel.post(welcome)

        # Get the first onboarding question from the LLM
        run_operation(llm, channel, config, "onboarding", activity=activity)
        # Save the LLM's first message to conversation history
        recent = channel.get_recent_history(limit=1)
        if recent and recent[0].is_bot:
            conversation.add_assistant_message(recent[0].text)

    # Cross-tasks (optional)
    cross_tasks = None
    if config.features.family:
        cross_tasks_path = os.path.join(
            os.path.dirname(config.notes_folder), "cross-tasks.json"
        )
        cross_tasks = CrossTaskChecker(cross_tasks_path, config.user_name, config.language)

    # Graceful shutdown
    running = True

    def handle_signal(signum, frame):
        nonlocal running
        print(f"\n[daemon] Received signal {signum}, shutting down...")
        activity.shutdown()
        running = False

    signal.signal(signal.SIGINT, handle_signal)
    signal.signal(signal.SIGTERM, handle_signal)

    # Polling intervals
    REMINDER_INTERVAL = 60       # Check reminders every 60s
    POLL_INTERVAL = 60           # Check messages every 60s

    last_reminder_check = 0
    last_message_check = 0

    print("[daemon] Starting main loop...")

    # Main loop
    while running:
        now = time.time()

        # 1. Fire due reminders (every minute)
        if now - last_reminder_check >= REMINDER_INTERVAL:
            fired = reminders.check_and_fire(channel)
            if fired > 0:
                for _ in range(fired):
                    activity.reminder_fired("(see reminders.json)")
            last_reminder_check = now

        # 2. Check for new messages (every 5 min)
        if now - last_message_check >= POLL_INTERVAL:
            new_msg = channel.check_for_new_message()
            activity.poll(new_msg is not None,
                         new_msg.text if new_msg else "")
            if new_msg:
                if config.language == "zh":
                    channel.post("收到 — 正在处理")
                else:
                    channel.post("Got it — working on this now")

                # Route: active conversation > needs onboarding > normal
                if conversation.is_active():
                    # Multi-turn conversation in progress
                    conv_type = conversation.get_type()
                    conversation.add_user_message(new_msg.text)
                    history = conversation.get_history_text()

                    run_operation(
                        llm, channel, config,
                        conv_type,
                        user_message=new_msg.text,
                        activity=activity,
                        conversation_history=history,
                    )

                    # Save assistant response to history
                    recent = channel.get_recent_history(limit=1)
                    if recent and recent[0].is_bot:
                        conversation.add_assistant_message(recent[0].text)

                        # Check if onboarding is truly complete:
                        # LLM said ONBOARDING_COMPLETE AND files no longer have placeholders
                        if "ONBOARDING_COMPLETE" in recent[0].text:
                            if not needs_onboarding(config):
                                print("[daemon] Onboarding complete — files updated")
                                conversation.end()
                                activity.log("onboarding", "Onboarding completed, files written")
                            else:
                                print("[daemon] LLM said complete but files still have placeholders — continuing")
                                activity.log("onboarding", "LLM said complete but files not updated, continuing")

                elif needs_onboarding(config):
                    # Not in active conversation but files still need onboarding
                    # Resume onboarding
                    print("[daemon] Files still need onboarding — resuming")
                    conversation.start("onboarding")
                    conversation.add_user_message(new_msg.text)

                    run_operation(
                        llm, channel, config,
                        "onboarding",
                        user_message=new_msg.text,
                        activity=activity,
                    )

                    recent = channel.get_recent_history(limit=1)
                    if recent and recent[0].is_bot:
                        conversation.add_assistant_message(recent[0].text)
                else:
                    # Normal message response
                    run_operation(
                        llm, channel, config,
                        "message_response",
                        user_message=new_msg.text,
                        activity=activity,
                    )
            last_message_check = now

        # 3. Run automations from Automations.md
        auto_count = check_automations(config.notes_folder, channel, llm, config)
        if auto_count > 0:
            activity.automation_fired(f"{auto_count} automation(s)", "mixed")

        # 4. Check cross-tasks (if family extension enabled)
        if cross_tasks:
            cross_tasks.check_and_notify(channel)

        # For --once mode (testing)
        if args.once:
            print("[daemon] --once mode, exiting after first cycle")
            activity.log("info", "--once mode, exiting")
            break

        # Sleep briefly to avoid busy-waiting
        time.sleep(10)

    print("[daemon] Stopped.")


if __name__ == "__main__":
    main()
