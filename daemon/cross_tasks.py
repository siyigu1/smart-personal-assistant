"""Cross-task checker — pure code, zero LLM tokens.

Checks cross-tasks.json for tasks assigned to this user and
posts notifications to the chat channel.
"""

import json
import os

from .channels.base import ChannelClient


class CrossTaskChecker:
    """Check for cross-task assignments and notify. No LLM involvement."""

    def __init__(self, cross_tasks_path: str, user_name: str):
        self.path = cross_tasks_path
        self.user_name = user_name

    def check_and_notify(self, channel: ChannelClient) -> int:
        """Check for pending tasks assigned to this user.

        Returns the number of notifications sent.
        """
        if not os.path.exists(self.path):
            return 0

        try:
            with open(self.path) as f:
                data = json.load(f)
        except (json.JSONDecodeError, OSError):
            return 0

        pending = data.get("pending", [])
        notified = 0

        for task in pending:
            if (task.get("to") == self.user_name
                    and not task.get("notified", False)):
                from_name = task.get("from", "Someone")
                description = task.get("task", "a task")
                channel.post(
                    f"{from_name} assigned you: {description}\n"
                    f"Reply 'accept' or 'reject'"
                )
                task["notified"] = True
                notified += 1

        if notified > 0:
            with open(self.path, "w") as f:
                json.dump(data, f, indent=2)

        return notified
