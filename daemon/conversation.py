"""Conversation state management for multi-turn interactions.

Tracks conversation history so the LLM can maintain context across
multiple stateless claude -p calls. Used for onboarding and
weekly planning sessions.
"""

import json
import os
import time
from typing import Optional


class Conversation:
    """Manages multi-turn conversation state.

    Stores the conversation history in a JSON file so it persists
    across daemon cycles. Each message has a role (user/assistant)
    and text.
    """

    def __init__(self, notes_folder: str):
        self.state_file = os.path.join(notes_folder, ".conversation-state.json")

    def is_active(self) -> bool:
        """Check if there's an active multi-turn conversation."""
        state = self._load()
        if not state.get("active"):
            return False
        # Auto-expire after 2 hours of inactivity
        last_ts = state.get("last_activity", 0)
        if time.time() - last_ts > 7200:
            self.end()
            return False
        return True

    def get_type(self) -> Optional[str]:
        """Get the type of active conversation (onboarding, weekly_planning, etc.)."""
        state = self._load()
        return state.get("type") if state.get("active") else None

    def start(self, conv_type: str) -> None:
        """Start a new multi-turn conversation."""
        self._save({
            "active": True,
            "type": conv_type,
            "messages": [],
            "started": time.time(),
            "last_activity": time.time(),
        })

    def add_user_message(self, text: str) -> None:
        """Add a user message to the conversation history."""
        state = self._load()
        state["messages"].append({"role": "user", "text": text})
        state["last_activity"] = time.time()
        self._save(state)

    def add_assistant_message(self, text: str) -> None:
        """Add an assistant response to the conversation history."""
        state = self._load()
        state["messages"].append({"role": "assistant", "text": text})
        state["last_activity"] = time.time()
        self._save(state)

    def get_history_text(self) -> str:
        """Get the full conversation history as formatted text."""
        state = self._load()
        lines = []
        for msg in state.get("messages", []):
            role = "User" if msg["role"] == "user" else "Assistant"
            lines.append(f"[{role}]: {msg['text']}")
        return "\n\n".join(lines)

    def get_message_count(self) -> int:
        """Get the number of messages in the conversation."""
        state = self._load()
        return len(state.get("messages", []))

    def end(self) -> None:
        """End the current conversation."""
        self._save({"active": False})

    def _load(self) -> dict:
        if not os.path.exists(self.state_file):
            return {"active": False}
        try:
            with open(self.state_file) as f:
                return json.load(f)
        except (json.JSONDecodeError, OSError):
            return {"active": False}

    def _save(self, state: dict) -> None:
        with open(self.state_file, "w") as f:
            json.dump(state, f, indent=2, ensure_ascii=False)
