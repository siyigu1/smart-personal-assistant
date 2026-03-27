"""Abstract base class for LLM provider integrations."""

from abc import ABC, abstractmethod
from dataclasses import dataclass, field


@dataclass
class LLMResponse:
    """Parsed response from an LLM invocation."""
    slack_message: str
    file_updates: dict[str, str] = field(default_factory=dict)
    raw: str = ""


class LLMBridge(ABC):
    """Abstract interface for LLM provider integrations.

    Implementations handle invoking a specific LLM (Claude CLI, OpenAI API,
    Ollama, etc.) with a text prompt and returning a text response.

    The LLM receives ALL context inline in the prompt (state files, system
    prompt, user message). It never accesses files or APIs directly.
    This means: no tool permissions, no MCP, no API keys for side services.
    The daemon handles all I/O.
    """

    @abstractmethod
    def invoke(self, prompt: str) -> str:
        """Send a prompt to the LLM and return the raw text response.

        Args:
            prompt: The full prompt including system instructions, context
                    files, and user message. Everything the LLM needs is
                    in this string.

        Returns:
            The LLM's text response, which the caller will parse for
            structured sections (SLACK_MESSAGE, FILE_UPDATES, etc.).
        """
        ...

    @abstractmethod
    def test_connection(self) -> bool:
        """Test that the LLM provider is accessible.

        Returns True if a simple prompt gets a response.
        """
        ...

    def parse_response(self, raw: str) -> LLMResponse:
        """Parse structured LLM output into an LLMResponse.

        Expected format:
            SLACK_MESSAGE:
            [message text]

            FILE_UPDATES:
            [path]|||[content]
            END_UPDATES

        If no structured format is found, the entire response is
        treated as the Slack message.
        """
        slack_message = raw
        file_updates = {}

        # Extract SLACK_MESSAGE section
        if "SLACK_MESSAGE:" in raw:
            parts = raw.split("SLACK_MESSAGE:", 1)
            remainder = parts[1]

            if "FILE_UPDATES:" in remainder:
                slack_message = remainder.split("FILE_UPDATES:", 1)[0].strip()
            else:
                slack_message = remainder.strip()

        # Extract FILE_UPDATES section
        if "FILE_UPDATES:" in raw and "END_UPDATES" in raw:
            updates_section = raw.split("FILE_UPDATES:", 1)[1]
            updates_section = updates_section.split("END_UPDATES", 1)[0].strip()

            for line in updates_section.split("\n"):
                if "|||" in line:
                    path, content = line.split("|||", 1)
                    file_updates[path.strip()] = content.strip()

        return LLMResponse(
            slack_message=slack_message,
            file_updates=file_updates,
            raw=raw,
        )
