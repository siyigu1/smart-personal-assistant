"""Build operation-specific prompts from state files.

Reads only the files needed for each operation to minimize
the prompt size sent to the LLM.
"""

import os
from typing import Optional


# Files needed per operation type
OPERATION_FILES = {
    "morning_dispatch": [
        "Workstreams.md",
        "Weekly Goals.md",
        "Daily Scaffolding.md",
    ],
    "midday_checkin": [
        "Weekly Goals.md",
    ],
    "afternoon_checkin": [
        "Weekly Goals.md",
    ],
    "eod_summary": [
        "Weekly Goals.md",
        "Workstreams.md",
    ],
    "weekly_review": [
        "Workstreams.md",
        "Weekly Goals.md",
    ],
    "weekly_planning": [
        "Workstreams.md",
        "Weekly Goals.md",
    ],
    "automation": [
        "Workstreams.md",
        "Weekly Goals.md",
        "Daily Scaffolding.md",
        "Cognitive Levels.md",
        "Priority Framework.md",
    ],
    "onboarding": [
        "Getting Started.md",
        "Cognitive Levels.md",
        "Daily Scaffolding.md",
        "Workstreams.md",
        "Weekly Goals.md",
    ],
    "message_response": [
        "Workstreams.md",
        "Weekly Goals.md",
        "Daily Scaffolding.md",
        "Cognitive Levels.md",
        "Priority Framework.md",
    ],
}


def read_file(path: str) -> Optional[str]:
    """Read a file and return its contents, or None if it doesn't exist."""
    if not os.path.exists(path):
        return None
    with open(path) as f:
        return f.read()


def build_prompt(
    notes_folder: str,
    operation: str,
    user_message: str = "",
    slack_history: str = "",
    conversation_history: str = "",
) -> str:
    """Build a complete prompt for an LLM invocation.

    Args:
        notes_folder: Path to the Personal Assistant notes folder.
        operation: The operation type (morning_dispatch, message_response, etc.)
        user_message: The user's message (for message_response operations).
        slack_history: Recent Slack conversation history (for context).
        conversation_history: Full multi-turn conversation history (for onboarding, etc.).

    Returns:
        A complete prompt string with system instructions and all
        relevant state files inline.
    """
    from .token_optimizer import (
        optimize_file_content,
        optimize_conversation_history,
        optimize_short_term_memory,
    )

    # Load and optimize system prompt
    start_here = os.path.join(notes_folder, "START HERE.md")
    skill_path = os.path.join(notes_folder, "skills", "mission-control", "SKILL.md")
    system_prompt = read_file(start_here) or read_file(skill_path) or ""
    system_prompt = optimize_file_content("START HERE.md", system_prompt)

    # Load and optimize playbook
    playbook_path = os.path.join(notes_folder, "Cowork Agent Playbook.md")
    playbook_raw = read_file(playbook_path) or ""
    playbook = optimize_file_content("Playbook.md", playbook_raw)

    # Load and optimize operation-specific state files
    files_needed = OPERATION_FILES.get(operation, OPERATION_FILES["message_response"])
    state_content = ""
    for filename in files_needed:
        file_path = os.path.join(notes_folder, filename)
        content = read_file(file_path)
        if content:
            optimized = optimize_file_content(filename, content)
            if optimized:
                state_content += f"\n\n--- {filename} ---\n{optimized}"

    # Build the full prompt
    prompt = f"""{system_prompt}

--- Playbook ---
{playbook}

--- State Files ---
{state_content}
"""

    if slack_history:
        prompt += f"\n--- Recent Slack ---\n{slack_history}\n"

    if conversation_history:
        optimized_history = optimize_conversation_history(conversation_history)
        prompt += f"\n--- Conversation ---\n{optimized_history}\n"

    # Load short-term memory (clean, no timestamps)
    stm_path = os.path.join(notes_folder, ".short-term-memory.json")
    if os.path.exists(stm_path):
        try:
            import json as _json
            with open(stm_path) as f:
                stm_raw = _json.load(f)
            stm_clean = optimize_short_term_memory(stm_raw)
            if stm_clean:
                stm_text = _json.dumps(stm_clean, ensure_ascii=False)
                prompt += f"\n--- Memory ---\n{stm_text}\n"
        except (ValueError, OSError):
            pass

    if operation == "automation":
        prompt += f"""
---
OPERATION: Scheduled automation.
Follow these instructions:

{user_message}

Use the state files above as context. Verify the day-of-week before stating it.
"""
    elif operation == "onboarding":
        if conversation_history:
            prompt += f"""
---
OPERATION: Onboarding — Continuing conversation.

You are in the middle of onboarding this user. The full conversation
so far is in the "Conversation So Far" section above.

The user just replied: {user_message}

Continue the interview from where you left off. Do NOT re-ask questions
they already answered. Use what they told you to build on the conversation.

When you have enough information to fill in ALL of these files, include
them in the "files" field of your JSON response:
- Workstreams
- Daily Scaffolding
- Weekly Goals
- Automations

Set "onboarding_complete" to true when you have collected enough
information and are writing the files.

If you still need more information, just ask the next questions
(with empty "files" and "onboarding_complete": false).
"""
        else:
            prompt += """
---
OPERATION: Onboarding — First-time user setup.

Read 'Getting Started.md' carefully. It contains the full interview guide.
Follow it step by step to learn about this user's life, schedule, and projects.

This is a multi-turn conversation. Ask 2-3 questions at a time, respond
warmly, then ask the next batch. Make it feel like a 15-minute chat.

Start with Part 1 from the Getting Started guide. Do NOT try to do
everything in one message — the user will reply and you'll continue.
"""
    elif operation == "message_response" and user_message:
        prompt += f"""
---
OPERATION: Respond to the user's message below.
Follow the acknowledgment-first workflow from the system prompt.
Classify any new items using the Priority Framework.
Update state files if needed.

USER MESSAGE:
{user_message}
"""
    elif operation == "morning_dispatch":
        prompt += """
---
OPERATION: Generate the Morning Dispatch.
Follow the Morning Dispatch template from the Playbook exactly.
Verify today's day-of-week before stating it.
"""
    elif operation == "midday_checkin":
        prompt += """
---
OPERATION: Generate the Midday Check-in.
Follow the Midday Check-in template from the Playbook.
Reference specific tasks from the morning dispatch. Keep it short (3-4 lines).
"""
    elif operation == "afternoon_checkin":
        prompt += """
---
OPERATION: Generate the Afternoon Check-in.
Follow the Afternoon Check-in template from the Playbook.
Suggest what can be done during low-capacity time. Keep it short.
"""
    elif operation == "eod_summary":
        prompt += """
---
OPERATION: Generate the End of Day Summary.
Follow the EOD Summary template from the Playbook.
Check if it's Friday — if so, include the Weekly Reflection appendix.
"""
    elif operation in ("weekly_review", "weekly_planning"):
        prompt += """
---
OPERATION: Generate the Weekly Planning post.
Follow the Sunday Night Weekly Planning template from the Playbook.
Summarize this week and suggest goals for next week.
"""

    # Output format instructions
    prompt += """
---
IMPORTANT: You have NO tool access. Do NOT try to read or write files directly.
Do NOT use any tools. You can only return JSON. The daemon handles all file I/O.

RESPOND WITH ONLY THIS JSON (no other text):

```json
{
  "messages": [
    "Your message to the user. Use Slack formatting: *bold* for emphasis."
  ],
  "files": {
    "Workstreams": "Complete new content for the entire Workstreams.md file",
    "Daily Scaffolding": "Complete new content for Daily Scaffolding.md"
  },
  "short_term_memory": {
    "key": "value — any info you need to remember across messages but that does not belong in the user's files"
  },
  "onboarding_complete": false
}
```

Rules:
- "messages": array of strings to post to chat. Usually one. Use Slack *bold* formatting.
- "files": filename (no .md) → complete file content. ONLY include files that changed. Omit if none.
- "short_term_memory": temp context to remember across messages (partial answers, clarifications, state). NOT saved to user files. Fed back to you next call. Use to avoid re-asking. Omit if empty.
- "onboarding_complete": true ONLY when you've gathered everything and are writing files
- File content = COMPLETE file, not a diff
- Keep your JSON compact — no unnecessary whitespace in file content. The daemon handles formatting.

If no file updates are needed, omit the FILE_UPDATES section entirely.
"""

    return prompt
