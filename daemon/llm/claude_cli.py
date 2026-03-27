"""Claude CLI LLM integration using `claude -p` (subscription-based)."""

import subprocess
import tempfile
import os

from .base import LLMBridge


class ClaudeCLI(LLMBridge):
    """Invoke Claude via the `claude` CLI tool.

    Uses `claude -p` which works with Claude Pro/Max subscription.
    No API key needed — uses OAuth login from `claude` CLI.

    The prompt is passed via a temp file to avoid shell escaping issues
    with long prompts containing markdown, code blocks, etc.
    """

    def __init__(self, timeout: int = 180):
        self.timeout = timeout

    def invoke(self, prompt: str) -> str:
        """Invoke claude -p with the given prompt."""
        # Write prompt to temp file to avoid shell escaping issues
        with tempfile.NamedTemporaryFile(
            mode="w", suffix=".md", delete=False
        ) as f:
            f.write(prompt)
            prompt_file = f.name

        try:
            result = subprocess.run(
                [
                    "claude",
                    "-p",
                    f"Read and follow the instructions in {prompt_file}",
                    "--output-format", "text",
                ],
                capture_output=True,
                text=True,
                timeout=self.timeout,
            )

            if result.returncode != 0:
                print(f"[claude] CLI error (exit {result.returncode}): {result.stderr}")
                return ""

            return result.stdout.strip()

        except subprocess.TimeoutExpired:
            print(f"[claude] Timed out after {self.timeout}s")
            return ""
        except FileNotFoundError:
            print("[claude] CLI not found. Install: https://docs.anthropic.com/en/docs/claude-code")
            return ""
        finally:
            os.unlink(prompt_file)

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
