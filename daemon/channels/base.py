"""Abstract base class for chat channel integrations."""

from abc import ABC, abstractmethod
from dataclasses import dataclass
from typing import Optional


@dataclass
class Message:
    """A message from a chat channel."""
    text: str
    user_id: str
    timestamp: str
    is_bot: bool = False
    thread_ts: Optional[str] = None


class ChannelClient(ABC):
    """Abstract interface for chat channel integrations.

    Implementations handle reading and posting messages to a specific
    chat platform (Slack, Discord, Telegram, etc.). The daemon uses
    this interface so it never needs to know which platform is in use.
    """

    @abstractmethod
    def check_for_new_message(self) -> Optional[Message]:
        """Check if there's a new user message that needs a response.

        Returns the message if one exists, None otherwise.
        This should track state internally (last seen timestamp)
        to avoid returning the same message twice.
        """
        ...

    @abstractmethod
    def post(self, text: str) -> None:
        """Post a message to the channel."""
        ...

    @abstractmethod
    def get_recent_history(self, limit: int = 10) -> list[Message]:
        """Get recent messages from the channel.

        Returns messages in reverse chronological order (newest first).
        """
        ...

    @abstractmethod
    def test_connection(self) -> bool:
        """Test that the channel connection is working.

        Returns True if a test message can be posted successfully.
        """
        ...
