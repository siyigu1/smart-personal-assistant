"""Read and execute automations from Automations.md.

Parses the markdown table in Automations.md and fires actions
when the current time matches. Supports two action types:
- 'message': post directly to channel (zero tokens)
- 'llm': send prompt to LLM, post response to channel
"""

import os
import re
import json
import time
from datetime import datetime, date
from dataclasses import dataclass
from typing import Optional


@dataclass
class Automation:
    """A single scheduled automation."""
    time: str           # HH:MM
    days: str           # weekdays, daily, monday, etc.
    action_type: str    # llm or message
    description: str
    prompt: str


# Tolerance window: action fires if within this many seconds of scheduled time
FIRE_WINDOW_SECONDS = 300  # 5 minutes


def parse_automations(notes_folder: str) -> list[Automation]:
    """Parse Automations.md and return list of automations."""
    path = os.path.join(notes_folder, "Automations.md")
    if not os.path.exists(path):
        return []

    with open(path) as f:
        content = f.read()

    # Find the markdown table rows (skip header and separator)
    automations = []
    in_table = False
    header_rows_skipped = 0

    for line in content.split("\n"):
        line = line.strip()
        if not line.startswith("|"):
            if in_table:
                break  # End of table
            continue

        if not in_table:
            in_table = True

        # Skip header row and separator row
        if header_rows_skipped < 2:
            header_rows_skipped += 1
            continue

        # Parse table row
        cells = [c.strip() for c in line.split("|")[1:-1]]  # Remove empty first/last from split
        if len(cells) < 5:
            continue

        time_str, days, action_type, description, prompt = (
            cells[0], cells[1], cells[2], cells[3], cells[4]
        )

        # Skip example/placeholder rows
        if time_str.startswith("_") or days == "disabled" or not time_str:
            continue

        # Validate time format
        if not re.match(r"^\d{2}:\d{2}$", time_str):
            continue

        automations.append(Automation(
            time=time_str,
            days=days.lower().strip(),
            action_type=action_type.lower().strip(),
            description=description,
            prompt=prompt,
        ))

    return automations


def should_fire(automation: Automation, now: Optional[datetime] = None) -> bool:
    """Check if an automation should fire right now."""
    if now is None:
        now = datetime.now()

    # Check day
    day_name = now.strftime("%A").lower()   # monday, tuesday, etc.
    weekday = now.weekday()                  # 0=Mon, 6=Sun

    days = automation.days
    if days == "daily":
        pass  # Always matches
    elif days == "weekdays":
        if weekday >= 5:
            return False
    elif days == "weekends":
        if weekday < 5:
            return False
    elif "," in days:
        # Comma-separated days
        allowed = [d.strip() for d in days.split(",")]
        if day_name not in allowed:
            return False
    else:
        # Single day name
        if day_name != days:
            return False

    # Check time (within tolerance window)
    try:
        hour, minute = map(int, automation.time.split(":"))
        scheduled_minutes = hour * 60 + minute
        current_minutes = now.hour * 60 + now.minute
        diff = abs(current_minutes - scheduled_minutes)
        return diff <= (FIRE_WINDOW_SECONDS // 60)
    except ValueError:
        return False


def get_fired_today_path(notes_folder: str) -> str:
    """Path to the file tracking which automations fired today."""
    return os.path.join(notes_folder, ".automations-fired.json")


def load_fired_today(notes_folder: str) -> dict:
    """Load the set of automations that already fired today."""
    path = get_fired_today_path(notes_folder)
    if not os.path.exists(path):
        return {"date": "", "fired": []}

    try:
        with open(path) as f:
            data = json.load(f)
    except (json.JSONDecodeError, OSError):
        return {"date": "", "fired": []}

    # Reset if it's a new day
    today = date.today().isoformat()
    if data.get("date") != today:
        return {"date": today, "fired": []}

    return data


def mark_fired(notes_folder: str, automation: Automation) -> None:
    """Mark an automation as fired today."""
    data = load_fired_today(notes_folder)
    data["date"] = date.today().isoformat()

    key = f"{automation.time}|{automation.description}"
    if key not in data["fired"]:
        data["fired"].append(key)

    path = get_fired_today_path(notes_folder)
    with open(path, "w") as f:
        json.dump(data, f)


def check_and_run(notes_folder: str, channel, llm, config) -> int:
    """Check all automations and run any that are due.

    Args:
        notes_folder: Path to notes folder containing Automations.md
        channel: ChannelClient for posting messages
        llm: LLMBridge for LLM-type actions
        config: Config object

    Returns:
        Number of automations fired.
    """
    from .context_builder import build_prompt
    from .file_updater import apply_updates

    automations = parse_automations(notes_folder)
    if not automations:
        return 0

    fired_data = load_fired_today(notes_folder)
    now = datetime.now()
    count = 0

    for auto in automations:
        key = f"{auto.time}|{auto.description}"

        # Skip if already fired today
        if key in fired_data.get("fired", []):
            continue

        if not should_fire(auto, now):
            continue

        print(f"[automations] Firing: {auto.description} ({auto.time})")

        if auto.action_type == "message":
            # Direct message — zero tokens
            channel.post(auto.prompt)
        elif auto.action_type == "llm":
            # LLM action — build prompt from automation's prompt field
            prompt = build_prompt(
                notes_folder=notes_folder,
                operation="automation",
                user_message=auto.prompt,
            )
            raw = llm.invoke(prompt)
            if raw:
                response = llm.parse_response(raw)
                if response.slack_message:
                    channel.post(response.slack_message)
                if response.file_updates:
                    apply_updates(response, notes_folder)

        mark_fired(notes_folder, auto)
        count += 1

    return count
