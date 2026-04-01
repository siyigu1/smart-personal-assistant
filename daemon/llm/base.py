"""Abstract base class for LLM provider integrations."""

from abc import ABC, abstractmethod
from dataclasses import dataclass, field


@dataclass
class LLMResponse:
    """Parsed response from an LLM invocation."""
    slack_message: str
    file_updates: dict = field(default_factory=dict)  # str→str (markdown files only)
    short_term_memory: dict = field(default_factory=dict)
    need_more_context: list = field(default_factory=list)
    onboarding_complete: bool = False
    add_automations: list = field(default_factory=list)
    update_automations: list = field(default_factory=list)
    remove_automations: list = field(default_factory=list)
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
        # Extract the JSON object from whatever the LLM returned.
        # Strategy: find the outermost {...} using brace counting.
        # This ignores any text before/after, code block markers,
        # language tags, etc.
        json_str = None
        brace_start = raw.find("{")
        if brace_start >= 0:
            depth = 0
            in_string = False
            escape_next = False
            for i in range(brace_start, len(raw)):
                ch = raw[i]
                if escape_next:
                    escape_next = False
                    continue
                if ch == '\\':
                    escape_next = True
                    continue
                if ch == '"' and not escape_next:
                    in_string = not in_string
                    continue
                if in_string:
                    continue
                if ch == '{':
                    depth += 1
                elif ch == '}':
                    depth -= 1
                    if depth == 0:
                        json_str = raw[brace_start:i + 1]
                        break

        if not json_str:
            # No JSON object found at all
            print(f"[parser] No JSON object found in response")
            print(f"[parser] First 200 chars: {raw[:200]}")
            return LLMResponse(
                slack_message=raw,
                file_updates={},
                raw=raw,
            )

        try:
            data = json.loads(json_str)
        except json.JSONDecodeError as e:
            print(f"[parser] JSON parse failed: {e}")
            print(f"[parser] Extracted JSON (first 300 chars): {json_str[:300]}")
            # Final fallback
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
            # Skip automations in files — use add/update/remove instead
            if key.lower() == "automations":
                continue
            # Normalize: "Workstreams" → "Workstreams.md"
            filename = key if key.endswith(".md") else f"{key}.md"
            file_updates[filename] = content

        # Extract short-term memory
        short_term_memory = data.get("short_term_memory", {})

        # Extract need_more_context
        need_more_context = data.get("need_more_context", [])
        if isinstance(need_more_context, str):
            need_more_context = [need_more_context]

        # Extract automation mutations
        add_automations = data.get("add_automations", [])
        if not isinstance(add_automations, list):
            add_automations = []
        update_automations = data.get("update_automations", [])
        if not isinstance(update_automations, list):
            update_automations = []
        remove_automations = data.get("remove_automations", [])
        if not isinstance(remove_automations, list):
            remove_automations = []

        # Check onboarding_complete flag
        onboarding_complete = bool(data.get("onboarding_complete", False))
        if onboarding_complete:
            slack_message += "\nONBOARDING_COMPLETE"

        return LLMResponse(
            slack_message=slack_message,
            file_updates=file_updates,
            short_term_memory=short_term_memory,
            need_more_context=need_more_context,
            onboarding_complete=onboarding_complete,
            add_automations=add_automations,
            update_automations=update_automations,
            remove_automations=remove_automations,
            raw=raw,
        )
