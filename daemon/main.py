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
    return "Not filled in yet" in content or "set during onboarding" in content


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
        def on_llm_error(error_type, message):
            """Post LLM errors to the user's Slack channel."""
            channel.post(f"⚠️ *Action needed:* {message}")

        return ClaudeCLI(timeout=180, on_error=on_llm_error)
    else:
        raise ValueError(f"Unknown LLM provider: {config.llm_provider}")


def run_operation(
    llm: LLMBridge,
    channel,
    config: Config,
    operation: str,
    user_message: str = "",
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
    )

    # Invoke the LLM
    print(f"[daemon] Invoking LLM for: {operation}")
    raw_response = llm.invoke(prompt)

    if not raw_response:
        print(f"[daemon] Empty response from LLM for: {operation}")
        return

    # Parse structured response
    response = llm.parse_response(raw_response)

    # Post to channel
    if response.slack_message:
        channel.post(response.slack_message)

    # Apply file updates
    if response.file_updates:
        updated = apply_updates(response, config.notes_folder)
        print(f"[daemon] Applied {updated} file update(s)")


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

    activity.startup(config.user_name, config.notes_folder)

    # Clean up old logs on startup
    deleted = activity.cleanup_old_logs()
    if deleted > 0:
        print(f"[daemon] Cleaned up {deleted} old log file(s)")

    # Check if onboarding is needed (first run)
    if needs_onboarding(config):
        print("[daemon] New user detected — starting onboarding conversation")
        activity.log("onboarding", "New user detected, starting onboarding")
        channel.post(
            f"Hi {config.user_name}! I'm your Personal Assistant. "
            f"Let's set up your system — I'll ask a few questions about "
            f"your schedule and projects. Takes about 15 minutes.\n\n"
            f"Ready to get started? (just reply 'yes' or 'let's go')"
        )
        run_operation(llm, channel, config, "onboarding")

    # Cross-tasks (optional)
    cross_tasks = None
    if config.features.family:
        cross_tasks_path = os.path.join(
            os.path.dirname(config.notes_folder), "cross-tasks.json"
        )
        cross_tasks = CrossTaskChecker(cross_tasks_path, config.user_name)

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
    POLL_INTERVAL = 300          # Check messages every 5 min

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
                channel.post("Got it — working on this now")
                t0 = time.time()
                run_operation(
                    llm, channel, config,
                    "message_response",
                    user_message=new_msg.text,
                )
                activity.llm_call("message_response",
                                  duration_sec=time.time() - t0,
                                  response_preview="(posted to Slack)")
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
