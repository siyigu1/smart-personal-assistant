"""Structured activity logging for the daemon.

Writes machine-readable JSON Lines to logs/activity.jsonl so the
status script can show a user-friendly dashboard. Also handles
log rotation (default: 7 days TTL).
"""

import json
import os
import time
from datetime import datetime, timedelta
from typing import Optional


class ActivityLog:
    """Structured activity logger.

    Each entry is a JSON line with:
    - ts: ISO timestamp
    - action: what happened (poll, reminder, automation, llm_call, error, etc.)
    - detail: human-readable summary
    - extra: optional dict with more info (llm input/output, etc.)
    """

    def __init__(self, log_dir: str, ttl_days: int = 7):
        self.log_dir = log_dir
        self.ttl_days = ttl_days
        self.activity_file = os.path.join(log_dir, "activity.jsonl")
        os.makedirs(log_dir, exist_ok=True)

    def log(
        self,
        action: str,
        detail: str,
        extra: Optional[dict] = None,
    ) -> None:
        """Write a structured log entry."""
        entry = {
            "ts": datetime.now().isoformat(),
            "action": action,
            "detail": detail,
        }
        if extra:
            entry["extra"] = extra

        with open(self.activity_file, "a") as f:
            f.write(json.dumps(entry) + "\n")

    def poll(self, had_message: bool, message_text: str = "") -> None:
        """Log a Slack poll cycle."""
        if had_message:
            self.log("poll", f"New message: {message_text[:80]}",
                     {"full_message": message_text})
        else:
            self.log("poll", "No new messages")

    def reminder_fired(self, message: str) -> None:
        """Log a reminder being fired."""
        self.log("reminder", f"Fired: {message}")

    def automation_fired(self, description: str, action_type: str) -> None:
        """Log a scheduled automation being fired."""
        self.log("automation", f"{description} ({action_type})")

    def automation_skipped(self, reason: str) -> None:
        """Log why automations were skipped this cycle."""
        self.log("automation_skip", reason)

    def llm_call(
        self,
        operation: str,
        prompt_tokens: int = 0,
        response_preview: str = "",
        duration_sec: float = 0,
    ) -> None:
        """Log an LLM invocation."""
        self.log("llm_call", f"{operation} ({duration_sec:.1f}s)", {
            "operation": operation,
            "prompt_tokens_approx": prompt_tokens,
            "response_preview": response_preview[:200],
            "duration_sec": round(duration_sec, 1),
        })

    def llm_error(self, operation: str, error: str) -> None:
        """Log an LLM error."""
        self.log("llm_error", f"{operation}: {error}", {"operation": operation})

    def error(self, detail: str) -> None:
        """Log a general error."""
        self.log("error", detail)

    def startup(self, user_name: str, notes_folder: str) -> None:
        """Log daemon startup."""
        self.log("startup", f"Daemon started for {user_name}",
                 {"notes_folder": notes_folder})

    def shutdown(self) -> None:
        """Log daemon shutdown."""
        self.log("shutdown", "Daemon stopped")

    def cleanup_old_logs(self) -> int:
        """Delete log files older than ttl_days.

        Cleans up:
        - Old setup-*.log and daemon-*.log files
        - Trims activity.jsonl to only keep entries within TTL

        Returns number of files deleted.
        """
        cutoff = time.time() - (self.ttl_days * 86400)
        deleted = 0

        # Clean old .log files
        for f in os.listdir(self.log_dir):
            if f.endswith(".log"):
                path = os.path.join(self.log_dir, f)
                if os.path.getmtime(path) < cutoff:
                    os.remove(path)
                    deleted += 1

        # Trim activity.jsonl
        if os.path.exists(self.activity_file):
            cutoff_iso = (datetime.now() - timedelta(days=self.ttl_days)).isoformat()
            kept_lines = []
            with open(self.activity_file) as f:
                for line in f:
                    line = line.strip()
                    if not line:
                        continue
                    try:
                        entry = json.loads(line)
                        if entry.get("ts", "") >= cutoff_iso:
                            kept_lines.append(line)
                    except json.JSONDecodeError:
                        continue

            with open(self.activity_file, "w") as f:
                f.write("\n".join(kept_lines) + "\n" if kept_lines else "")

        return deleted
