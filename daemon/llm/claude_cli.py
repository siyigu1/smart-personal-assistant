"""Claude CLI LLM integration using `claude -p` (subscription-based)."""

import subprocess
from enum import Enum

from .base import LLMBridge


class ClaudeError(Enum):
    """Known Claude CLI error types."""
    AUTH_REQUIRED = "auth_required"       # 401 — needs manual login
    RATE_LIMITED = "rate_limited"          # 429 — too many requests
    UPDATE_REQUIRED = "update_required"   # CLI needs update
    UNKNOWN = "unknown"


class ClaudeCLI(LLMBridge):
    """Invoke Claude via the `claude` CLI tool.

    Uses `claude -p` which works with Claude Pro/Max subscription.
    No API key needed — uses OAuth login from `claude` CLI.

    The prompt is passed via a temp file to avoid shell escaping issues
    with long prompts containing markdown, code blocks, etc.
    """

    # Error patterns to detect in stderr/stdout
    AUTH_PATTERNS = [
        "401",
        "unauthorized",
        "auth",
        "login",
        "sign in",
        "session expired",
        "token expired",
        "not authenticated",
        "authentication required",
    ]

    UPDATE_PATTERNS = [
        "update required",
        "upgrade",
        "new version available",
        "please update",
    ]

    def __init__(self, timeout: int = 180, on_error=None):
        """
        Args:
            timeout: Max seconds to wait for Claude CLI response.
            on_error: Optional callback fn(error_type: ClaudeError, message: str)
                      called when a recoverable error is detected. The daemon
                      uses this to post Slack notifications.
        """
        self.timeout = timeout
        self.on_error = on_error

    def invoke(self, prompt: str) -> str:
        """Invoke claude -p with the given prompt.

        Passes the prompt via stdin to avoid both shell escaping issues
        and temp file permission problems (Claude CLI can't read /var/folders/).
        """
        try:
            result = subprocess.run(
                [
                    "claude",
                    "-p",
                    "--output-format", "text",
                    "--tools", "",
                ],
                input=prompt,
                capture_output=True,
                text=True,
                timeout=self.timeout,
            )

            if result.returncode != 0:
                error_text = (result.stderr + result.stdout).lower()
                error_type = self._classify_error(error_text)

                if error_type == ClaudeError.AUTH_REQUIRED:
                    print(f"[claude] Auth required — notifying user")
                    self._notify_error(ClaudeError.AUTH_REQUIRED, "auth_required")
                elif error_type == ClaudeError.UPDATE_REQUIRED:
                    print(f"[claude] Update required — notifying user")
                    self._notify_error(ClaudeError.UPDATE_REQUIRED, "update_required")
                else:
                    print(f"[claude] CLI error (exit {result.returncode}): {result.stderr}")
                    self._notify_error(ClaudeError.UNKNOWN, f"unknown:{result.returncode}")

                return ""

            return result.stdout.strip()

        except subprocess.TimeoutExpired:
            print(f"[claude] Timed out after {self.timeout}s")
            return ""
        except FileNotFoundError:
            print("[claude] CLI not found. Install: https://docs.anthropic.com/en/docs/claude-code")
            return ""

    def _classify_error(self, error_text: str) -> ClaudeError:
        """Classify an error based on stderr/stdout content."""
        for pattern in self.AUTH_PATTERNS:
            if pattern in error_text:
                return ClaudeError.AUTH_REQUIRED

        for pattern in self.UPDATE_PATTERNS:
            if pattern in error_text:
                return ClaudeError.UPDATE_REQUIRED

        return ClaudeError.UNKNOWN

    def _notify_error(self, error_type: ClaudeError, message: str) -> None:
        """Send error notification via the callback."""
        if self.on_error:
            self.on_error(error_type, message)

    def test_connection(self) -> bool:
        """Test Claude CLI is available and logged in."""
        try:
            result = subprocess.run(
                ["claude", "--version"],
                capture_output=True,
                text=True,
                timeout=10,
            )
            if result.returncode == 0:
                print(f"[claude] CLI version: {result.stdout.strip()}")
                return True
            return False
        except (FileNotFoundError, subprocess.TimeoutExpired):
            return False
