"""Token optimization — strip noise before sending to LLM, expand on return.

The daemon preprocesses context to minimize input tokens and tells the
LLM to return compact output. The daemon then expands compact output
back to human-readable format for files and Slack messages.
"""

import re
import json
import os
from typing import Optional


def optimize_file_content(filename: str, content: str) -> str:
    """Strip noise from a file before including in the LLM prompt.

    Removes:
    - HTML comments (<!-- ... -->)
    - Markdown blockquote instructions (> lines that explain how the file works)
    - Empty placeholder text ("_(empty)_", "_(none configured)_")
    - Repeated blank lines
    - Template variable markers ({{...}})
    """
    lines = content.split("\n")
    result = []
    skip_blockquote_block = False

    for line in lines:
        stripped = line.strip()

        # Skip HTML comments
        if "<!--" in stripped and "-->" in stripped:
            continue
        if "<!--" in stripped:
            skip_blockquote_block = True
            continue
        if "-->" in stripped:
            skip_blockquote_block = False
            continue
        if skip_blockquote_block:
            continue

        # Skip instruction blockquotes (> lines that explain how to use the file)
        # Keep blockquotes that contain actual data (priority order, source of truth, etc.)
        if stripped.startswith(">"):
            lower = stripped.lower()
            skip_phrases = [
                "how this works",
                "not filled in yet",
                "尚未填写",
                "share `getting started",
                "分享 `getting started",
                "this file is filled",
                "give this file to any ai",
                "tell your agent",
                "告诉你的 agent",
                "for the ai:",
                "给 ai 的说明",
                "for bot/daemon",
                "给机器人",
            ]
            if any(phrase in lower for phrase in skip_phrases):
                continue

        # Skip empty placeholders
        if stripped in ("_(empty)_", "_(none configured)_", "_(none)_",
                        "_（在这里添加想法）_", "_(Add ideas here)_"):
            continue

        # Skip raw template markers
        if "{{" in stripped and "}}" in stripped:
            continue

        result.append(line)

    # Collapse multiple blank lines into one
    output = "\n".join(result)
    output = re.sub(r"\n{3,}", "\n\n", output)

    return output.strip()


def optimize_conversation_history(history: str, max_messages: int = 20) -> str:
    """Compact conversation history to save tokens.

    Keeps the most recent messages in full. Older messages get summarized
    to just key facts extracted from them.
    """
    if not history:
        return ""

    lines = history.split("\n\n")
    if len(lines) <= max_messages:
        return history

    # Keep last max_messages in full, summarize the rest
    recent = lines[-max_messages:]
    old = lines[:-max_messages]

    # Compact old messages: just role + first 80 chars
    summary_lines = []
    for msg in old:
        if msg.startswith("[User]:"):
            text = msg[7:].strip()[:80]
            summary_lines.append(f"[User]: {text}...")
        elif msg.startswith("[Assistant]:"):
            text = msg[12:].strip()[:80]
            summary_lines.append(f"[Assistant]: {text}...")

    summary = "\n".join(summary_lines)
    recent_text = "\n\n".join(recent)

    return f"(Earlier messages, summarized):\n{summary}\n\n(Recent messages, full):\n{recent_text}"


def optimize_short_term_memory(stm_raw: dict) -> dict:
    """Clean short-term memory for LLM consumption.

    Strips internal metadata (timestamps, etc.) and returns
    only the key-value pairs the LLM needs.
    """
    clean = {}
    for key, value in stm_raw.items():
        if isinstance(value, dict) and "value" in value:
            # Strip TTL metadata
            clean[key] = value["value"]
        else:
            clean[key] = value
    return clean


def optimize_prompt_files(notes_folder: str, filenames: list[str]) -> str:
    """Read and optimize multiple files for inclusion in a prompt."""
    from .context_builder import read_file

    content = ""
    for filename in filenames:
        path = os.path.join(notes_folder, filename)
        raw = read_file(path)
        if raw:
            optimized = optimize_file_content(filename, raw)
            if optimized:
                content += f"\n\n--- {filename} ---\n{optimized}"
    return content
