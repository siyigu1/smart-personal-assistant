"""Personal Assistant Daemon — main entry point.

Lightweight Python daemon that handles deterministic work (polling,
automations, scheduling) and invokes the LLM only when intelligence
is needed.

Supports two modes:
- Socket Mode (preferred): instant message handling via Slack Events API
- Polling Mode (fallback): checks for new messages every 60 seconds
"""

import os
import sys
import time
import signal
import asyncio
import argparse
import threading
from datetime import datetime
from typing import Optional

from .config import load_config, Config
from .i18n import t
from .llm.claude_cli import ClaudeCLI
from .llm.base import LLMBridge
from .automations import check_and_run as check_automations
from .context_builder import build_prompt
from .file_updater import apply_updates
from .activity_log import ActivityLog
from .user_context import UserContext, create_user_contexts
from .maintenance import run_maintenance


def needs_onboarding(notes_folder: str) -> bool:
    """Check if a user needs onboarding (first run).

    Returns True if the Workstreams.md file still contains the
    onboarding placeholder text, meaning the AI hasn't interviewed
    the user yet.
    """
    ws_path = os.path.join(notes_folder, "Workstreams.md")
    if not os.path.exists(ws_path):
        return True
    with open(ws_path) as f:
        content = f.read()
    markers = [
        "Not filled in yet",
        "set during onboarding",
        "尚未填写",
        "入门设置时填写",
        "{{WORKSTREAM_SECTIONS}}",
        "（在这里添加想法）",
        "_(Add ideas here",
    ]
    return any(m in content for m in markers)


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

# Per-user lock to prevent simultaneous LLM calls for the same user
# (e.g., Socket Mode handler + scheduled loop both firing at once)
_user_locks: dict[str, threading.Lock] = {}


def _get_user_lock(user_name: str) -> threading.Lock:
    """Get or create a per-user threading lock."""
    if user_name not in _user_locks:
        _user_locks[user_name] = threading.Lock()
    return _user_locks[user_name]


_ERROR_KEY_MAP = {
    "auth_required": "error_auth",
    "update_required": "error_update",
}


def _llm_error_notifier(channel, config):
    """Create an error callback that notifies Slack once per error type."""
    def on_error(error_type, message_key):
        if error_type.value in _notified_errors:
            return
        _notified_errors.add(error_type.value)
        lang = config.language
        prefix = t("error_prefix", lang)
        i18n_key = _ERROR_KEY_MAP.get(message_key)
        if i18n_key:
            detail = t(i18n_key, lang)
        elif message_key.startswith("unknown:"):
            code = message_key.split(":")[1]
            detail = t("error_unknown_code", lang, code=code)
        else:
            detail = message_key
        channel.post(f"\u26a0\ufe0f *{prefix}:* {detail}")
    return on_error


def notify_llm_failure(channel, operation: str, config=None, activity=None):
    """Notify user via Slack that an LLM call failed. Only once."""
    key = f"llm_failure_{operation}"
    if key in _notified_errors:
        return
    _notified_errors.add(key)
    lang = config.language if config else "en"
    channel.post(t("error_llm_failure", lang, operation=operation))
    if activity:
        activity.llm_error(operation, "Empty response from LLM")


def run_operation(
    llm: LLMBridge,
    user: UserContext,
    config: Config,
    operation: str,
    user_message: str = "",
    activity: Optional[ActivityLog] = None,
    conversation_history: str = "",
):
    """Run an LLM-powered operation and post results.

    This is the only function that invokes the LLM. Everything else
    in the daemon is pure code. Supports Turn 2 via need_more_context.

    Acquires a per-user lock to prevent simultaneous LLM calls for
    the same user (e.g., Socket Mode handler + scheduled loop).
    """
    lock = _get_user_lock(user.user_name)
    with lock:
        _run_operation_locked(llm, user, config, operation,
                              user_message, activity, conversation_history)


def _run_operation_locked(
    llm: LLMBridge,
    user: UserContext,
    config: Config,
    operation: str,
    user_message: str = "",
    activity: Optional[ActivityLog] = None,
    conversation_history: str = "",
):
    """Internal: run an LLM operation while holding the user lock."""
    channel = user.channel

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
        notes_folder=user.notes_folder,
        operation=operation,
        user_message=user_message,
        slack_history=slack_history,
        conversation_history=conversation_history,
        data_dir=user.data_dir,
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

    # Handle need_more_context — Turn 2
    if response.need_more_context and not conversation_history:
        print(f"[daemon] LLM requests more context: {response.need_more_context}")
        # Re-invoke with additional files
        prompt2 = build_prompt(
            notes_folder=user.notes_folder,
            operation=operation,
            user_message=user_message,
            slack_history=slack_history,
            conversation_history=conversation_history,
            data_dir=user.data_dir,
            extra_files=response.need_more_context,
        )
        raw_response2 = llm.invoke(prompt2)
        if raw_response2:
            response = llm.parse_response(raw_response2)
            duration += time.time() - t0

    # Post to channel (strip internal markers)
    if response.slack_message:
        clean_msg = response.slack_message.replace("ONBOARDING_COMPLETE", "").strip()
        if clean_msg:
            channel.post(clean_msg)

    # Apply file updates
    if response.file_updates:
        updated = apply_updates(response, user.notes_folder, data_dir=user.data_dir)
        print(f"[daemon] Applied {updated} file update(s)")

    # Save short-term memory with timestamps for TTL
    if response.short_term_memory:
        import json as _json
        stm_path = os.path.join(user.data_dir, "short-term-memory.json")

        # Load existing, merge new entries with timestamps
        existing = {}
        if os.path.exists(stm_path):
            try:
                with open(stm_path) as f:
                    existing = _json.load(f)
            except (ValueError, OSError):
                pass

        now_ts = time.time()
        for key, value in response.short_term_memory.items():
            existing[key] = {"value": value, "ts": now_ts}

        # Prune entries older than 7 days
        cutoff = now_ts - 604800  # 7 days
        existing = {k: v for k, v in existing.items()
                    if isinstance(v, dict) and v.get("ts", 0) > cutoff}

        with open(stm_path, "w") as f:
            _json.dump(existing, f, indent=2, ensure_ascii=False)
        print(f"[daemon] Short-term memory: {len(existing)} entries")

    # Handle manual tidy trigger
    if response.trigger_tidy:
        from .maintenance import tidy_context
        print(f"[daemon] User requested context tidying")
        tidy_context(
            user.data_dir, user.notes_folder, llm, config,
            lang=user.language if hasattr(user, 'language') else 'en',
            force=True, activity=activity,
        )

    # Log the call
    if activity:
        activity.llm_call(
            operation=operation,
            prompt_tokens=len(prompt) // 4,  # rough estimate
            response_preview=response.slack_message[:200] if response.slack_message else "",
            duration_sec=duration,
        )


def _build_channel_user_map(users: list[UserContext]) -> dict[str, UserContext]:
    """Build a mapping from channel_id to UserContext for Socket Mode routing."""
    return {u.slack_channel_id: u for u in users}


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

    # Create LLM (shared across all users — same Claude CLI)
    # Use primary user's channel for error notifications
    users = create_user_contexts(config)
    llm = create_llm(config, users[0].channel)

    print(f"[daemon] Users: {', '.join(u.user_name for u in users)}")
    for u in users:
        print(f"[daemon]   {u.user_name}: {u.slack_channel_name} → notes={u.notes_folder}, data={u.data_dir}")
    print(f"[daemon] LLM: {config.llm_provider}")

    activity.startup(
        ", ".join(u.user_name for u in users),
        config.notes_folder,
    )

    # Clean up old logs on startup
    deleted = activity.cleanup_old_logs()
    if deleted > 0:
        print(f"[daemon] Cleaned up {deleted} old log file(s)")

    # Check onboarding for each user
    for user in users:
        if needs_onboarding(user.notes_folder) and not user.conversation.is_active():
            print(f"[daemon] New user {user.user_name} — starting onboarding")
            activity.log("onboarding", f"Starting onboarding for {user.user_name}")
            user.conversation.start("onboarding")

            welcome = t(
                "welcome_onboarding", user.language,
                user_name=user.user_name,
                assistant_name=user.assistant_name,
            )
            user.channel.post(welcome)
            run_operation(llm, user, config, "onboarding", activity=activity)

            recent = user.channel.get_recent_history(limit=1)
            if recent and recent[0].is_bot:
                user.conversation.add_assistant_message(recent[0].text)

    # Try Socket Mode, fall back to polling
    if config.slack_app_token and not args.once:
        try:
            _run_socket_mode(config, users, llm, activity, args)
            return  # Socket Mode ran successfully (blocks until shutdown)
        except Exception as e:
            print(f"[daemon] Socket Mode failed ({e}), falling back to polling")

    # Polling mode (fallback or --once)
    _run_polling(config, users, llm, activity, args)


def _run_socket_mode(config, users, llm, activity, args):
    """Run the daemon in Socket Mode — instant message handling."""
    from .channels.slack_socket import create_socket_app

    channel_map = _build_channel_user_map(users)

    def handle_message(channel_id: str, text: str, say_fn):
        """Handle an incoming Slack message from Socket Mode."""
        user = channel_map.get(channel_id)
        if not user:
            print(f"[socket] Message from unknown channel {channel_id}, ignoring")
            return

        print(f"[socket] Message from {user.user_name}: {text[:80]}")

        say_fn(t("ack", user.language))

        # Route: active conversation > needs onboarding > normal
        if user.conversation.is_active():
            conv_type = user.conversation.get_type()
            user.conversation.add_user_message(text)
            history = user.conversation.get_history_text()

            run_operation(
                llm, user, config, conv_type,
                user_message=text,
                activity=activity,
                conversation_history=history,
            )

            recent = user.channel.get_recent_history(limit=1)
            if recent and recent[0].is_bot:
                user.conversation.add_assistant_message(recent[0].text)
                if "ONBOARDING_COMPLETE" in recent[0].text:
                    if not needs_onboarding(user.notes_folder):
                        print(f"[daemon] Onboarding complete for {user.user_name}")
                        user.conversation.end()
                        activity.log("onboarding", f"{user.user_name}: completed")

        elif needs_onboarding(user.notes_folder):
            print(f"[daemon] {user.user_name}: resuming onboarding")
            user.conversation.start("onboarding")
            user.conversation.add_user_message(text)

            run_operation(
                llm, user, config, "onboarding",
                user_message=text, activity=activity,
            )

            recent = user.channel.get_recent_history(limit=1)
            if recent and recent[0].is_bot:
                user.conversation.add_assistant_message(recent[0].text)
        else:
            run_operation(
                llm, user, config, "message_response",
                user_message=text, activity=activity,
            )

    async def scheduled_loop():
        """Background loop for automations, cross-tasks."""
        while True:
            for user in users:
                try:
                    # 1. Run automations (includes message-type, formerly reminders)
                    auto_count = check_automations(
                        user.data_dir, user.notes_folder,
                        user.channel, llm, config
                    )
                    if auto_count > 0:
                        activity.automation_fired(
                            f"{user.user_name}: {auto_count} automation(s)", "mixed"
                        )

                    # 2. Check cross-tasks
                    if user.cross_tasks:
                        user.cross_tasks.check_and_notify(user.channel)

                    # 3. Run maintenance (each task checks its own schedule)
                    run_maintenance(
                        user.data_dir, user.notes_folder,
                        user.channel, llm, config,
                        lang=user.language, activity=activity,
                    )
                except Exception as e:
                    print(f"[scheduled] Error for {user.user_name}: {e}")

            await asyncio.sleep(60)

    print("[daemon] Starting Socket Mode...")
    app, handler = create_socket_app(
        bot_token=config.slack_bot_token,
        app_token=config.slack_app_token,
        on_message=handle_message,
    )

    async def run():
        asyncio.create_task(scheduled_loop())
        await handler.start_async()

    asyncio.run(run())


def _run_polling(config, users, llm, activity, args):
    """Run the daemon in polling mode (fallback)."""
    print("[daemon] Starting polling mode...")

    # Graceful shutdown
    running = True

    def handle_signal(signum, frame):
        nonlocal running
        print(f"\n[daemon] Received signal {signum}, shutting down...")
        activity.shutdown()
        running = False

    signal.signal(signal.SIGINT, handle_signal)
    signal.signal(signal.SIGTERM, handle_signal)

    # Round-robin: one user per cycle
    user_index = 0
    CYCLE_INTERVAL = 60

    last_cycle = 0

    print("[daemon] Starting main loop...")

    # Main loop — round-robin: one user per cycle
    while running:
        now = time.time()

        if now - last_cycle < CYCLE_INTERVAL:
            time.sleep(10)
            continue

        # Pick the current user for this cycle
        user = users[user_index % len(users)]
        user_index += 1
        last_cycle = now

        print(f"[cycle] {user.user_name} ({user.slack_channel_name})")

        # 1. Check for new messages
        new_msg = user.channel.check_for_new_message()
        activity.poll(new_msg is not None,
                     f"{user.user_name}: {new_msg.text}" if new_msg else user.user_name)

        if new_msg:
            user.channel.post(t("ack", user.language))

            # Route: active conversation > needs onboarding > normal
            if user.conversation.is_active():
                conv_type = user.conversation.get_type()
                user.conversation.add_user_message(new_msg.text)
                history = user.conversation.get_history_text()

                run_operation(
                    llm, user, config, conv_type,
                    user_message=new_msg.text,
                    activity=activity,
                    conversation_history=history,
                )

                recent = user.channel.get_recent_history(limit=1)
                if recent and recent[0].is_bot:
                    user.conversation.add_assistant_message(recent[0].text)

                    if "ONBOARDING_COMPLETE" in recent[0].text:
                        if not needs_onboarding(user.notes_folder):
                            print(f"[daemon] Onboarding complete for {user.user_name}")
                            user.conversation.end()
                            activity.log("onboarding", f"{user.user_name}: completed")
                        else:
                            print(f"[daemon] {user.user_name}: LLM said complete but files still have placeholders")

            elif needs_onboarding(user.notes_folder):
                print(f"[daemon] {user.user_name}: resuming onboarding")
                user.conversation.start("onboarding")
                user.conversation.add_user_message(new_msg.text)

                run_operation(
                    llm, user, config, "onboarding",
                    user_message=new_msg.text, activity=activity,
                )

                recent = user.channel.get_recent_history(limit=1)
                if recent and recent[0].is_bot:
                    user.conversation.add_assistant_message(recent[0].text)
            else:
                run_operation(
                    llm, user, config, "message_response",
                    user_message=new_msg.text, activity=activity,
                )

        # 2. Run automations from this user's data dir (includes message-type, formerly reminders)
        auto_count = check_automations(
            user.data_dir, user.notes_folder,
            user.channel, llm, config
        )
        if auto_count > 0:
            activity.automation_fired(f"{user.user_name}: {auto_count} automation(s)", "mixed")

        # 3. Check cross-tasks
        if user.cross_tasks:
            user.cross_tasks.check_and_notify(user.channel)

        # 4. Run maintenance (each task checks its own schedule)
        run_maintenance(
            user.data_dir, user.notes_folder,
            user.channel, llm, config,
            lang=user.language, activity=activity,
        )

        # For --once mode (testing) — run one cycle per user then exit
        if args.once and user_index >= len(users):
            print("[daemon] --once mode, exiting after one round")
            activity.log("info", "--once mode, exiting")
            break

    print("[daemon] Stopped.")


if __name__ == "__main__":
    main()
