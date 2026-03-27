"""Reminder engine — pure code, zero LLM tokens.

Reads reminders.json, fires any due reminders to the chat channel,
and marks them as fired.
"""

import json
import os
import time

from .channels.base import ChannelClient


class ReminderEngine:
    """Check and fire due reminders. No LLM involvement."""

    def __init__(self, notes_folder: str):
        self.path = os.path.join(notes_folder, "reminders.json")

    def check_and_fire(self, channel: ChannelClient) -> int:
        """Check for due reminders and fire them.

        Returns the number of reminders fired.
        """
        if not os.path.exists(self.path):
            return 0

        try:
            with open(self.path) as f:
                reminders = json.load(f)
        except (json.JSONDecodeError, OSError):
            return 0

        now = int(time.time())
        fired_count = 0

        for r in reminders:
            if r.get("due_ts", 0) <= now and not r.get("fired", False):
                channel.post(r["message"])
                r["fired"] = True
                fired_count += 1

        if fired_count > 0:
            with open(self.path, "w") as f:
                json.dump(reminders, f, indent=2)
            print(f"[reminders] Fired {fired_count} reminder(s)")

        return fired_count
