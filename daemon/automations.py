"""Read and execute automations from automations.json.

Automations are the unified system for all scheduled actions, including
what was previously called "reminders" (now automations with action: "message").

Reads strict JSON from data/{user}/automations.json and fires actions
when the current time matches. Supports three action types:
- 'message': post directly to channel (zero tokens) — replaces reminders
- 'cached': post from a pre-generated cache file (zero tokens)
- 'llm': send prompt to LLM, post response to channel

The daemon is the writer and reader of automations.json.
It also renders Automations.md in the user's Obsidian folder
as a human-readable view.

Incremental mutation functions (add/update/remove) let the LLM
modify automations without rewriting the entire list.
"""

import hashlib
import os
import json
import re
import time
from datetime import datetime, date
from typing import Optional


# Tolerance window: action fires if within this many seconds of scheduled time
FIRE_WINDOW_SECONDS = 300  # 5 minutes


def _generate_id(name: str, time_str: str = "") -> str:
    """Generate a 4-char hex ID from name + time."""
    data = f"{name}|{time_str}|{time.time()}"
    return hashlib.sha256(data.encode()).hexdigest()[:4]


def _ensure_ids(automations: list[dict]) -> list[dict]:
    """Ensure every automation has a unique 'id' field."""
    existing_ids = {a.get("id") for a in automations if a.get("id")}
    for auto in automations:
        if not auto.get("id"):
            new_id = _generate_id(auto.get("name", ""), auto.get("time", ""))
            while new_id in existing_ids:
                new_id = hashlib.sha256(
                    f"{new_id}{time.time()}".encode()
                ).hexdigest()[:4]
            auto["id"] = new_id
            existing_ids.add(new_id)
    return automations


def _normalize_when(when) -> dict:
    """Normalize a 'when' field to a dict with 'days' and/or 'dates' arrays.

    Handles shorthand strings like "weekdays", "sunday", "daily", etc.
    """
    if isinstance(when, dict):
        return when
    if not isinstance(when, str):
        return {}
    w = when.lower().strip()
    if w == "weekdays":
        return {"days": ["mon", "tue", "wed", "thu", "fri"]}
    if w in ("everyday", "daily"):
        return {"days": ["mon", "tue", "wed", "thu", "fri", "sat", "sun"]}
    if w == "weekends":
        return {"days": ["sat", "sun"]}
    if w in ("mon", "tue", "wed", "thu", "fri", "sat", "sun",
             "monday", "tuesday", "wednesday", "thursday",
             "friday", "saturday", "sunday"):
        return {"days": [w[:3]]}
    return {}


def _is_one_time_date(date_str: str) -> bool:
    """Check if a date string is a one-time date (YYYY-MM-DD format)."""
    return bool(re.match(r'^\d{4}-\d{2}-\d{2}$', date_str))


def should_fire(auto: dict, now: Optional[datetime] = None) -> bool:
    """Check if an automation should fire right now based on its 'when' field.

    The 'when' field uses two optional fields (at least one required):
    - days: array of 3-letter weekday codes ["mon","tue","wed",...]
    - dates: array of "MM-DD" (yearly) or "YYYY-MM-DD" (one-time)

    Fires if EITHER days or dates matches.
    """
    if now is None:
        now = datetime.now()

    when = _normalize_when(auto.get("when", {}))

    # Check day-of-week match
    day_match = now.strftime("%a").lower() in when.get("days", [])

    # Check date match
    date_match = any(
        now.strftime("%m-%d") == d if len(d) == 5
        else now.strftime("%Y-%m-%d") == d
        for d in when.get("dates", [])
    )

    if not (day_match or date_match):
        return False

    # Check time (within tolerance window)
    try:
        hour, minute = map(int, auto["time"].split(":"))
        scheduled_minutes = hour * 60 + minute
        current_minutes = now.hour * 60 + now.minute
        diff = abs(current_minutes - scheduled_minutes)
        return diff <= (FIRE_WINDOW_SECONDS // 60)
    except (ValueError, KeyError):
        return False


def load_automations(data_dir: str) -> list[dict]:
    """Load automations from the data directory's automations.json."""
    path = os.path.join(data_dir, "automations.json")
    if not os.path.exists(path):
        return []
    try:
        with open(path) as f:
            data = json.load(f)
        if isinstance(data, list):
            return data
        return []
    except (json.JSONDecodeError, OSError):
        return []


def _save_automations(data_dir: str, automations: list[dict]) -> None:
    """Save automations list to automations.json."""
    json_path = os.path.join(data_dir, "automations.json")
    with open(json_path, "w") as f:
        json.dump(automations, f, indent=2, ensure_ascii=False)


def load_fired_today(data_dir: str) -> dict:
    """Load the set of automations that already fired today."""
    path = os.path.join(data_dir, "automations-fired.json")
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


def mark_fired(data_dir: str, auto: dict) -> None:
    """Mark an automation as fired today."""
    data = load_fired_today(data_dir)
    data["date"] = date.today().isoformat()

    key = auto.get("id") or f"{auto.get('time', '')}|{auto.get('name', '')}"
    if key not in data["fired"]:
        data["fired"].append(key)

    path = os.path.join(data_dir, "automations-fired.json")
    with open(path, "w") as f:
        json.dump(data, f)


# ── Incremental mutation functions ────────────────────────────────


def add_automations(data_dir: str, notes_folder: str, new_items: list[dict]) -> int:
    """Add new automations to the existing list.

    Each new item gets a daemon-assigned 4-char hex ID.

    Returns:
        Number of automations added.
    """
    automations = load_automations(data_dir)
    new_items = _ensure_ids(new_items)
    automations.extend(new_items)
    _save_automations(data_dir, automations)
    render_automations_md(notes_folder, automations)
    print(f"[automations] Added {len(new_items)} automation(s)")
    return len(new_items)


def update_automations(data_dir: str, notes_folder: str, updates: list[dict]) -> int:
    """Update existing automations by ID.

    Each dict in updates must have an 'id' field. All other fields
    are merged into the existing automation.

    Returns:
        Number of automations updated.
    """
    automations = load_automations(data_dir)
    by_id = {a["id"]: a for a in automations if "id" in a}
    count = 0

    for upd in updates:
        aid = upd.get("id")
        if aid and aid in by_id:
            by_id[aid].update(upd)
            count += 1
        else:
            print(f"[automations] Update skipped — id '{aid}' not found")

    if count > 0:
        _save_automations(data_dir, automations)
        render_automations_md(notes_folder, automations)
        print(f"[automations] Updated {count} automation(s)")
    return count


def remove_automations(data_dir: str, notes_folder: str, ids: list[str]) -> int:
    """Remove automations by ID.

    Returns:
        Number of automations removed.
    """
    automations = load_automations(data_dir)
    ids_set = set(ids)
    before = len(automations)
    automations = [a for a in automations if a.get("id") not in ids_set]
    removed = before - len(automations)

    if removed > 0:
        _save_automations(data_dir, automations)
        render_automations_md(notes_folder, automations)
        print(f"[automations] Removed {removed} automation(s)")
    return removed


def cleanup_one_time(data_dir: str, notes_folder: str) -> int:
    """Remove one-time automations (YYYY-MM-DD dates) that have already fired.

    Called after firing. Entries whose 'when.dates' contains only past
    YYYY-MM-DD dates (and no recurring 'days') are removed.

    Returns:
        Number of automations cleaned up.
    """
    automations = load_automations(data_dir)
    today = date.today().isoformat()
    keep = []
    removed = 0

    for auto in automations:
        when = _normalize_when(auto.get("when", {}))
        days = when.get("days", [])
        dates = when.get("dates", [])

        # Keep if it has recurring days
        if days:
            keep.append(auto)
            continue

        # Check if all dates are one-time and in the past
        one_time_dates = [d for d in dates if _is_one_time_date(d)]
        recurring_dates = [d for d in dates if not _is_one_time_date(d)]

        if one_time_dates and not recurring_dates:
            # All dates are one-time; remove if all are past
            if all(d <= today for d in one_time_dates):
                removed += 1
                continue

        keep.append(auto)

    if removed > 0:
        _save_automations(data_dir, keep)
        render_automations_md(notes_folder, keep)
        print(f"[automations] Cleaned up {removed} expired one-time automation(s)")

    return removed


def get_automation_summary(data_dir: str) -> str:
    """Return a compact summary of all automations.

    Format: id:Name@HH:MM/day1,day2,day3
    Example: a3f2:Morning Dispatch@08:00/mon,tue,wed,thu,fri
    """
    automations = load_automations(data_dir)
    automations = _ensure_ids(automations)
    lines = []
    for auto in automations:
        aid = auto.get("id", "????")
        name = auto.get("name", "unnamed")
        time_str = auto.get("time", "??:??")
        when = _normalize_when(auto.get("when", {}))
        schedule_parts = []
        if "days" in when:
            schedule_parts.append(",".join(when["days"]))
        if "dates" in when:
            schedule_parts.append(",".join(when["dates"]))
        schedule = "/".join(schedule_parts) if schedule_parts else "none"
        lines.append(f"{aid}:{name}@{time_str}/{schedule}")
    return "\n".join(lines)


def write_automations(data_dir: str, notes_folder: str, automations: list[dict]) -> None:
    """Write automations to both JSON (for daemon) and Markdown (for user).

    This is the full-replace version. Prefer add/update/remove for
    incremental changes.

    Args:
        data_dir: Path to data/{user_id}/ for automations.json
        notes_folder: Path to user's Obsidian folder for Automations.md
        automations: List of automation dicts from LLM response
    """
    automations = _ensure_ids(automations)
    _save_automations(data_dir, automations)
    print(f"[automations] Wrote {len(automations)} automation(s) to automations.json")

    # Render Markdown (human-readable view in Obsidian)
    render_automations_md(notes_folder, automations)


def render_automations_md(notes_folder: str, automations: list[dict]) -> None:
    """Render Automations.md from automation data for user viewing."""
    lines = [
        "# Automations",
        "",
        "_This file is auto-generated by the daemon. Edit automations by telling the bot._",
        "",
        "| ID | Time | Schedule | Type | Name | Details |",
        "|----|------|----------|------|------|---------|",
    ]

    for auto in automations:
        aid = auto.get("id", "")
        time_str = auto.get("time", "")
        when = _normalize_when(auto.get("when", {}))
        action = auto.get("action", "")
        name = auto.get("name", "")

        # Format schedule
        schedule_parts = []
        if "days" in when:
            schedule_parts.append(", ".join(when["days"]))
        if "dates" in when:
            schedule_parts.append(", ".join(when["dates"]))
        schedule = "; ".join(schedule_parts)

        # Format details
        if action == "message":
            details = auto.get("text", "")
        elif action == "llm":
            details = auto.get("prompt", "")[:50] + ("..." if len(auto.get("prompt", "")) > 50 else "")
        elif action == "cached":
            details = auto.get("cache_file", "")
        else:
            details = ""

        # Escape pipe chars in table cells
        details = details.replace("|", "\\|").replace("\n", " ")
        name = name.replace("|", "\\|")

        lines.append(f"| {aid} | {time_str} | {schedule} | {action} | {name} | {details} |")

    md_path = os.path.join(notes_folder, "Automations.md")
    with open(md_path, "w") as f:
        f.write("\n".join(lines) + "\n")
    print(f"[automations] Rendered Automations.md")


def check_and_run(data_dir: str, notes_folder: str, channel, llm, config) -> int:
    """Check all automations and run any that are due.

    Args:
        data_dir: Path to data/{user_id}/ containing automations.json
        notes_folder: Path to notes folder for building prompts
        channel: ChannelClient for posting messages
        llm: LLMBridge for LLM-type actions
        config: Config object

    Returns:
        Number of automations fired.
    """
    from .context_builder import build_prompt
    from .file_updater import apply_updates

    automations = load_automations(data_dir)
    if not automations:
        return 0

    fired_data = load_fired_today(data_dir)
    now = datetime.now()
    count = 0

    for auto in automations:
        key = auto.get("id") or f"{auto.get('time', '')}|{auto.get('name', '')}"

        # Skip if already fired today
        if key in fired_data.get("fired", []):
            continue

        if not should_fire(auto, now):
            continue

        action = auto.get("action", "")
        name = auto.get("name", key)

        try:
            print(f"[automations] Firing: {name} ({auto.get('time', '')})")

            if action == "message":
                # Direct message — zero tokens
                text = auto.get("text", "")
                if text:
                    channel.post(text)
            elif action == "cached":
                # Post from cache file — zero tokens
                cache_file = auto.get("cache_file", "")
                if cache_file:
                    cache_path = os.path.join(data_dir, cache_file)
                    if os.path.exists(cache_path):
                        with open(cache_path) as f:
                            channel.post(f.read())
                    else:
                        print(f"[automations] Cache file not found: {cache_path}")
            elif action == "llm":
                # LLM action — build prompt from automation's prompt field
                prompt_text = auto.get("prompt", "")
                if prompt_text:
                    prompt = build_prompt(
                        notes_folder=notes_folder,
                        operation="automation",
                        user_message=prompt_text,
                        data_dir=data_dir,
                    )
                    raw = llm.invoke(prompt)
                    if raw:
                        response = llm.parse_response(raw)
                        if response.slack_message:
                            channel.post(response.slack_message)
                        if response.file_updates:
                            apply_updates(response, notes_folder, data_dir=data_dir)

            mark_fired(data_dir, auto)
            count += 1
        except Exception as e:
            print(f"[automations] Error firing '{name}': {e}")
            import traceback
            traceback.print_exc()
            # Mark as fired to avoid retrying a broken automation every cycle
            mark_fired(data_dir, auto)

    # Auto-cleanup: remove expired one-time entries after firing
    if count > 0:
        cleanup_one_time(data_dir, notes_folder)

    return count
