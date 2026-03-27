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
) -> str:
    """Build a complete prompt for an LLM invocation.

    Args:
        notes_folder: Path to the Personal Assistant notes folder.
        operation: The operation type (morning_dispatch, message_response, etc.)
        user_message: The user's message (for message_response operations).
        slack_history: Recent Slack conversation history (for context).

    Returns:
        A complete prompt string with system instructions and all
        relevant state files inline.
    """
    # Load system prompt (the "kernel")
    skill_path = os.path.join(notes_folder, "skills", "mission-control", "SKILL.md")
    system_prompt = read_file(skill_path) or ""

    # Load playbook
    playbook_path = os.path.join(notes_folder, "Cowork Agent Playbook.md")
    playbook = read_file(playbook_path) or ""

    # Load operation-specific state files
    files_needed = OPERATION_FILES.get(operation, OPERATION_FILES["message_response"])
    state_content = ""
    for filename in files_needed:
        file_path = os.path.join(notes_folder, filename)
        content = read_file(file_path)
        if content:
            state_content += f"\n\n--- {filename} ---\n{content}"

    # Build the full prompt
    prompt = f"""{system_prompt}

--- Cowork Agent Playbook.md ---
{playbook}

--- Current State Files ---
{state_content}
"""

    if slack_history:
        prompt += f"\n--- Recent Slack Conversation ---\n{slack_history}\n"

    if operation == "message_response" and user_message:
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
FORMAT YOUR RESPONSE EXACTLY LIKE THIS:

SLACK_MESSAGE:
[Your complete message to post to Slack. Use Slack formatting: *bold* for emphasis, numbered lists for options.]

FILE_UPDATES:
[Only include this section if state files need to be updated]
[Full file path]|||[Complete new content for the file section that changed]
END_UPDATES

If no file updates are needed, omit the FILE_UPDATES section entirely.
"""

    return prompt
