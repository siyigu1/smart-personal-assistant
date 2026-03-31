"""Abstract base class for LLM provider integrations."""

from abc import ABC, abstractmethod
from dataclasses import dataclass, field


@dataclass
class LLMResponse:
    """Parsed response from an LLM invocation."""
    slack_message: str
    file_updates: dict[str, str] = field(default_factory=dict)
    short_term_memory: dict = field(default_factory=dict)
    onboarding_complete: bool = False
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
        """Parse JSON response from the LLM.

        Expected format:
        {
          "messages": ["message to post to Slack", "optional second message"],
          "files": {
            "Workstreams": "full file content...",
            "Daily Scaffolding": "full file content..."
          },
          "onboarding_complete": true
        }

        The "files" keys are matched to actual filenames by appending .md.
        If the response is not valid JSON, treat the entire text as a
        Slack message (graceful fallback).
        """
        import json

        raw = raw.strip()

        # Try to extract JSON from the response
        # LLM might wrap it in ```json ... ``` or have text before/after
        json_str = raw

        # Strip code block wrappers (```json ... ``` or just ``` ... ```)
        if "```json" in raw:
            json_str = raw.split("```json", 1)[1].split("```", 1)[0].strip()
        elif "```" in raw:
            json_str = raw.split("```", 1)[1].split("```", 1)[0].strip()

        # Handle case where --output-format text strips backticks,
        # leaving "json\n{...}" at the start
        if json_str.startswith("json\n"):
            json_str = json_str[5:].strip()
        elif json_str.startswith("json\r\n"):
            json_str = json_str[6:].strip()

        # Find the JSON object in the response
        if not json_str.startswith("{"):
            start = json_str.find("{")
            if start >= 0:
                json_str = json_str[start:]

        try:
            data = json.loads(json_str)
        except json.JSONDecodeError as e:
            print(f"[parser] JSON parse failed: {e}")
            print(f"[parser] First 200 chars: {json_str[:200]}")
            print(f"[parser] Last 200 chars: {json_str[-200:]}")

            # Try fixing common issues: unescaped newlines in strings
            try:
                # Sometimes LLM outputs literal newlines inside JSON strings
                # Try to fix by finding the JSON object boundaries
                brace_count = 0
                json_end = -1
                for i, ch in enumerate(json_str):
                    if ch == '{':
                        brace_count += 1
                    elif ch == '}':
                        brace_count -= 1
                        if brace_count == 0:
                            json_end = i + 1
                            break
                if json_end > 0:
                    data = json.loads(json_str[:json_end])
                else:
                    raise
            except (json.JSONDecodeError, Exception):
                # Final fallback: treat entire response as a Slack message
                print(f"[parser] All parse attempts failed, using raw text as message")
                return LLMResponse(
                    slack_message=raw,
                    file_updates={},
                    raw=raw,
                )

        # Extract messages
        messages = data.get("messages", [])
        if isinstance(messages, str):
            messages = [messages]
        slack_message = "\n\n".join(messages)

        # Extract file updates — keys map to filenames
        files = data.get("files", {})
        file_updates = {}
        for key, content in files.items():
            # Normalize: "Workstreams" → "Workstreams.md"
            filename = key if key.endswith(".md") else f"{key}.md"
            file_updates[filename] = content

        # Extract short-term memory
        short_term_memory = data.get("short_term_memory", {})

        # Check onboarding_complete flag
        onboarding_complete = bool(data.get("onboarding_complete", False))
        if onboarding_complete:
            slack_message += "\nONBOARDING_COMPLETE"

        return LLMResponse(
            slack_message=slack_message,
            file_updates=file_updates,
            short_term_memory=short_term_memory,
            onboarding_complete=onboarding_complete,
            raw=raw,
        )
