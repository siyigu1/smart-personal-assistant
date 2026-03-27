"""Slack channel integration using slack-sdk."""

import json
import os
from typing import Optional

from slack_sdk import WebClient
from slack_sdk.errors import SlackApiError

from .base import ChannelClient, Message


class SlackChannel(ChannelClient):
    """Slack channel integration.

    Uses the Slack SDK to read and post messages. Requires a Bot User
    OAuth Token (xoxb-...) with scopes: channels:history, channels:read,
    chat:write.
    """

    def __init__(self, bot_token: str, channel_id: str, state_file: str):
        self.client = WebClient(token=bot_token)
        self.channel_id = channel_id
        self.state_file = state_file
        self.last_seen_ts = self._load_last_seen()

    def check_for_new_message(self) -> Optional[Message]:
        """Check for new user messages since last bot reply."""
        try:
            result = self.client.conversations_history(
                channel=self.channel_id, limit=10
            )
        except SlackApiError as e:
            print(f"[slack] Error reading history: {e}")
            return None

        messages = result.get("messages", [])

        for msg in messages:
            # Skip bot messages
            if msg.get("bot_id") or msg.get("subtype") == "bot_message":
                continue
            # Skip reactions-only or empty
            if not msg.get("text", "").strip():
                continue

            msg_ts = float(msg["ts"])
            if msg_ts > self.last_seen_ts:
                self.last_seen_ts = msg_ts
                self._save_last_seen()
                return Message(
                    text=msg["text"],
                    user_id=msg.get("user", "unknown"),
                    timestamp=msg["ts"],
                    is_bot=False,
                    thread_ts=msg.get("thread_ts"),
                )

        return None

    def post(self, text: str) -> None:
        """Post a message to the Slack channel."""
        try:
            self.client.chat_postMessage(
                channel=self.channel_id,
                text=text,
            )
        except SlackApiError as e:
            print(f"[slack] Error posting message: {e}")

    def get_recent_history(self, limit: int = 10) -> list[Message]:
        """Get recent channel messages."""
        try:
            result = self.client.conversations_history(
                channel=self.channel_id, limit=limit
            )
        except SlackApiError as e:
            print(f"[slack] Error reading history: {e}")
            return []

        messages = []
        for msg in result.get("messages", []):
            messages.append(Message(
                text=msg.get("text", ""),
                user_id=msg.get("user", msg.get("bot_id", "unknown")),
                timestamp=msg["ts"],
                is_bot=bool(msg.get("bot_id") or msg.get("subtype") == "bot_message"),
                thread_ts=msg.get("thread_ts"),
            ))
        return messages

    def test_connection(self) -> bool:
        """Test Slack connection by posting a test message."""
        try:
            self.client.chat_postMessage(
                channel=self.channel_id,
                text="Personal Assistant is connected! Ready to help.",
            )
            return True
        except SlackApiError as e:
            print(f"[slack] Connection test failed: {e}")
            return False

    def _load_last_seen(self) -> float:
        """Load last seen message timestamp from state file."""
        if os.path.exists(self.state_file):
            try:
                with open(self.state_file) as f:
                    state = json.load(f)
                return state.get("last_seen_ts", 0.0)
            except (json.JSONDecodeError, OSError):
                pass
        return 0.0

    def _save_last_seen(self) -> None:
        """Save last seen message timestamp to state file."""
        state = {}
        if os.path.exists(self.state_file):
            try:
                with open(self.state_file) as f:
                    state = json.load(f)
            except (json.JSONDecodeError, OSError):
                pass

        state["last_seen_ts"] = self.last_seen_ts
        with open(self.state_file, "w") as f:
            json.dump(state, f, indent=2)
