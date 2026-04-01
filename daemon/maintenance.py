"""Automated maintenance tasks that run on a schedule.

These are internal daemon tasks — not user-configured automations.
They run independently of automations.json. Run during maintenance
window (1am-4am) to avoid interrupting the user.

Results are written to System Notices.md in the user's notes folder.
The LLM picks these up and weaves them into the morning dispatch.

Tasks:
1. Memory consolidation (every 7 days) — move STM → Preferences.md
2. Context tidying (every 7 days) — archive completed tasks, clean up files
3. OS update check (daily) — check for available system updates
4. AI CLI update check (daily) — check if claude CLI has updates
"""

import os
import json
import time
import subprocess
import platform
from datetime import datetime, date
from typing import Optional

from .activity_log import ActivityLog


def _add_system_notice(notes_folder: str, notice: str) -> None:
    """Add a notice to System Notices.md for the LLM to pick up.

    The LLM reads this file during morning dispatch and includes
    relevant notices in its message to the user. Notices are
    timestamped so the LLM can tell what's new.
    """
    path = os.path.join(notes_folder, "System Notices.md")
    timestamp = datetime.now().strftime("%Y-%m-%d %H:%M")

    existing = ""
    if os.path.exists(path):
        with open(path) as f:
            existing = f.read()

    # Prepend new notice at the top
    entry = f"- [{timestamp}] {notice}"
    if existing.strip():
        # Keep only last 20 notices to prevent file growth
        lines = existing.strip().split("\n")
        header_lines = []
        notice_lines = []
        for line in lines:
            if line.startswith("- [") or line.startswith("  "):
                notice_lines.append(line)
            elif line.startswith("#"):
                header_lines.append(line)
        notice_lines = notice_lines[:19]  # Keep 19 + new one = 20
        content = "\n".join(header_lines) + "\n\n" + entry + "\n" + "\n".join(notice_lines) + "\n"
    else:
        content = "# System Notices\n\n_The assistant reads these during morning dispatch._\n\n" + entry + "\n"

    with open(path, "w") as f:
        f.write(content)


# ─── State tracking ─────────────────────────────────────────────

def _load_maintenance_state(data_dir: str) -> dict:
    """Load maintenance state (last run dates)."""
    path = os.path.join(data_dir, "maintenance-state.json")
    if not os.path.exists(path):
        return {}
    try:
        with open(path) as f:
            return json.load(f)
    except (json.JSONDecodeError, OSError):
        return {}


def _save_maintenance_state(data_dir: str, state: dict) -> None:
    """Save maintenance state."""
    path = os.path.join(data_dir, "maintenance-state.json")
    with open(path, "w") as f:
        json.dump(state, f, indent=2)


def _should_run(state: dict, task: str, interval_days: int) -> bool:
    """Check if a maintenance task should run based on last run date."""
    last_run = state.get(task)
    if not last_run:
        return True
    try:
        last_date = datetime.fromisoformat(last_run).date()
        return (date.today() - last_date).days >= interval_days
    except (ValueError, TypeError):
        return True


def _mark_done(state: dict, task: str) -> dict:
    """Mark a maintenance task as done today."""
    state[task] = datetime.now().isoformat()
    return state


# ─── Memory Consolidation ───────────────────────────────────────

def consolidate_memory(
    data_dir: str,
    notes_folder: str,
    llm,
    config,
    activity: Optional[ActivityLog] = None,
) -> bool:
    """Move important short-term memory items to Preferences.md.

    Invokes the LLM to review STM and decide what to keep long-term.
    Runs every 7 days.

    Returns True if consolidation ran.
    """
    state = _load_maintenance_state(data_dir)
    if not _should_run(state, "memory_consolidation", 7):
        return False

    # Load STM
    stm_path = os.path.join(data_dir, "short-term-memory.json")
    if not os.path.exists(stm_path):
        _save_maintenance_state(data_dir, _mark_done(state, "memory_consolidation"))
        return False

    try:
        with open(stm_path) as f:
            stm = json.load(f)
    except (json.JSONDecodeError, OSError):
        return False

    if not stm:
        _save_maintenance_state(data_dir, _mark_done(state, "memory_consolidation"))
        return False

    # Load current Preferences.md
    prefs_path = os.path.join(notes_folder, "Preferences.md")
    prefs_content = ""
    if os.path.exists(prefs_path):
        with open(prefs_path) as f:
            prefs_content = f.read()

    # Strip timestamps from STM for the prompt
    stm_clean = {}
    for k, v in stm.items():
        if isinstance(v, dict) and "value" in v:
            stm_clean[k] = v["value"]
        else:
            stm_clean[k] = v

    # Ask LLM to consolidate
    prompt = f"""You are reviewing short-term memory for a personal assistant.

Current short-term memory (will expire in 7 days):
{json.dumps(stm_clean, indent=2, ensure_ascii=False)}

Current Preferences.md (long-term memory):
{prefs_content}

Task: Review the short-term memory items. If any contain important user preferences,
habits, or rules that should be remembered permanently, add them to the appropriate
section of Preferences.md.

Return JSON:
{{
  "messages": [],
  "files": {{
    "Preferences": "complete updated Preferences.md content"
  }},
  "short_term_memory": {{}}
}}

Only include "files" if Preferences.md needs updating.
Set short_term_memory to empty object to clear it after consolidation.
If nothing needs to move to long-term, just return empty messages and files.
"""

    print("[maintenance] Running memory consolidation...")
    raw = llm.invoke(prompt)
    if raw:
        response = llm.parse_response(raw)
        if response.file_updates:
            from .file_updater import apply_updates
            apply_updates(response, notes_folder, data_dir=data_dir)
            print("[maintenance] Preferences.md updated from STM")

        # Clear STM after consolidation
        with open(stm_path, "w") as f:
            json.dump({}, f)
        print("[maintenance] Short-term memory cleared")

    if activity:
        activity.log("maintenance", "Memory consolidation completed")

    _save_maintenance_state(data_dir, _mark_done(state, "memory_consolidation"))
    return True


# ─── OS Update Check ────────────────────────────────────────────

def check_os_updates(
    data_dir: str,
    notes_folder: str,
    activity: Optional[ActivityLog] = None,
) -> bool:
    """Check for available OS updates. Pure code, no LLM.

    Runs daily. Writes to System Notices.md for LLM to include
    in morning dispatch.
    Returns True if check ran.
    """
    state = _load_maintenance_state(data_dir)
    if not _should_run(state, "os_update_check", 1):
        return False

    system = platform.system()
    updates = []

    try:
        if system == "Darwin":  # macOS
            result = subprocess.run(
                ["softwareupdate", "-l"],
                capture_output=True, text=True, timeout=60,
            )
            output = result.stdout + result.stderr
            # Parse available updates
            for line in output.split("\n"):
                line = line.strip()
                if line.startswith("*") or "Label:" in line:
                    updates.append(line.lstrip("* ").strip())
                elif "Title:" in line:
                    updates.append(line.strip())

        elif system == "Linux":
            # Try apt (Debian/Ubuntu)
            result = subprocess.run(
                ["apt", "list", "--upgradable"],
                capture_output=True, text=True, timeout=60,
            )
            if result.returncode == 0:
                for line in result.stdout.split("\n"):
                    if "/" in line and "upgradable" in line.lower():
                        updates.append(line.split("/")[0])

    except (subprocess.TimeoutExpired, FileNotFoundError, OSError):
        pass

    if updates:
        update_names = ", ".join(updates[:3])
        if len(updates) > 3:
            update_names += f" (+{len(updates) - 3} more)"
        notice = f"OS updates available: {update_names}. Install when convenient."
        _add_system_notice(notes_folder, notice)
        print(f"[maintenance] {len(updates)} OS update(s) available")

        if activity:
            activity.log("maintenance", f"OS updates available: {len(updates)}")
    else:
        print("[maintenance] OS is up to date")

    _save_maintenance_state(data_dir, _mark_done(state, "os_update_check"))
    return True


# ─── AI CLI Update Check ────────────────────────────────────────

def check_ai_cli_updates(
    data_dir: str,
    notes_folder: str,
    activity: Optional[ActivityLog] = None,
) -> bool:
    """Check if the AI CLI tool (claude) has updates available.

    Runs daily. Writes to System Notices.md for LLM to include
    in morning dispatch.
    Returns True if check ran.
    """
    state = _load_maintenance_state(data_dir)
    if not _should_run(state, "ai_cli_update_check", 1):
        return False

    try:
        # Check claude CLI version
        result = subprocess.run(
            ["claude", "--version"],
            capture_output=True, text=True, timeout=10,
        )
        current_version = result.stdout.strip() if result.returncode == 0 else "unknown"

        # Check if update is available via claude update --check (if supported)
        update_result = subprocess.run(
            ["claude", "update", "--check"],
            capture_output=True, text=True, timeout=30,
        )
        output = (update_result.stdout + update_result.stderr).lower()

        needs_update = False
        if "update available" in output or "new version" in output:
            needs_update = True
        elif update_result.returncode != 0 and "update" in output:
            needs_update = True

        if needs_update:
            notice = f"AI CLI update available (current: {current_version}). Run `claude update` to upgrade."
            _add_system_notice(notes_folder, notice)
            print(f"[maintenance] AI CLI update available (current: {current_version})")

            if activity:
                activity.log("maintenance", f"AI CLI update available: {current_version}")
        else:
            print(f"[maintenance] AI CLI is up to date ({current_version})")

    except (FileNotFoundError, subprocess.TimeoutExpired, OSError):
        print("[maintenance] Could not check AI CLI version")

    _save_maintenance_state(data_dir, _mark_done(state, "ai_cli_update_check"))
    return True


# ─── Context Tidying ────────────────────────────────────────────

def _get_quarter(d: date) -> str:
    """Get quarter label for a date: '2026-Q1', '2026-Q2', etc."""
    q = (d.month - 1) // 3 + 1
    return f"{d.year}-Q{q}"


def tidy_context(
    data_dir: str,
    notes_folder: str,
    llm,
    config,
    lang: str = "en",
    force: bool = False,
    activity: Optional[ActivityLog] = None,
) -> bool:
    """Clean up framework files maintained by LLM.

    - Moves completed tasks to quarterly archive (archive/2026-Q2.md)
    - Cleans up workstream pending items
    - Reorganizes and deduplicates
    - Updates Weekly Goals to reflect current state

    Runs every 7 days automatically, or on demand (force=True).
    Returns True if tidying ran.
    """
    state = _load_maintenance_state(data_dir)
    if not force and not _should_run(state, "context_tidy", 7):
        return False

    # Read all user files that need tidying
    files_to_tidy = [
        "Workstreams.md",
        "Weekly Goals.md",
        "Daily Scaffolding.md",
    ]

    file_contents = {}
    for fname in files_to_tidy:
        path = os.path.join(notes_folder, fname)
        if os.path.exists(path):
            with open(path) as f:
                file_contents[fname] = f.read()

    if not file_contents:
        _save_maintenance_state(data_dir, _mark_done(state, "context_tidy"))
        return False

    # Load existing archive for this quarter
    quarter = _get_quarter(date.today())
    archive_dir = os.path.join(notes_folder, "archive")
    os.makedirs(archive_dir, exist_ok=True)
    archive_path = os.path.join(archive_dir, f"{quarter}.md")
    existing_archive = ""
    if os.path.exists(archive_path):
        with open(archive_path) as f:
            existing_archive = f.read()

    # Build file content for prompt
    files_text = ""
    for fname, content in file_contents.items():
        files_text += f"\n--- {fname} ---\n{content}\n"

    if lang == "zh":
        tidy_prompt = f"""你是一个文件整理助手。请整理以下用户的框架文件。

当前日期：{date.today().isoformat()}
当前季度：{quarter}

当前文件：
{files_text}

当前季度归档文件（{quarter}.md）：
{existing_archive if existing_archive else "（空）"}

请执行以下操作：

1. **Workstreams.md**：
   - 将所有已完成的任务移到归档文件（{quarter}.md）
   - 只保留待办、进行中的任务
   - 确保每个工作流有清晰的待办列表
   - 更新决策日志（保留重要决策，归档旧的）
   - 更新上下文切换包以反映当前状态

2. **Weekly Goals.md**：
   - 清理已完成的目标
   - 将上周的完成记录移到归档
   - 保持本周目标干净

3. **Daily Scaffolding.md**：
   - 清理过期的临时日程备注
   - 保持基础日程框架不变

4. **归档文件 {quarter}.md**：
   - 将所有移出的已完成任务添加到这里
   - 按工作流和日期组织
   - 包含重要的决策和里程碑

返回 JSON：
{{
  "messages": ["整理完成的简要总结"],
  "files": {{
    "Workstreams": "整理后的完整 Workstreams.md 内容",
    "Weekly Goals": "整理后的完整 Weekly Goals.md 内容",
    "Daily Scaffolding": "整理后的完整 Daily Scaffolding.md 内容",
    "archive/{quarter}": "更新后的季度归档内容"
  }}
}}
"""
    else:
        tidy_prompt = f"""You are a file maintenance assistant. Tidy up the user's framework files.

Current date: {date.today().isoformat()}
Current quarter: {quarter}

Current files:
{files_text}

Current quarterly archive ({quarter}.md):
{existing_archive if existing_archive else "(empty)"}

Perform these operations:

1. **Workstreams.md**:
   - Move ALL completed tasks to the archive file ({quarter}.md)
   - Keep only pending and in-progress tasks
   - Ensure each workstream has a clean pending task list
   - Update decision logs (keep important decisions, archive old ones)
   - Update pick-up packets to reflect current state

2. **Weekly Goals.md**:
   - Clean up completed goals
   - Move last week's completion records to archive
   - Keep current week's goals clean

3. **Daily Scaffolding.md**:
   - Remove expired temporary schedule notes
   - Keep the base schedule framework intact

4. **Archive file {quarter}.md**:
   - Add all moved completed tasks here
   - Organize by workstream and date
   - Include important decisions and milestones

Return JSON:
{{
  "messages": ["Brief summary of what was tidied"],
  "files": {{
    "Workstreams": "complete tidied Workstreams.md content",
    "Weekly Goals": "complete tidied Weekly Goals.md content",
    "Daily Scaffolding": "complete tidied Daily Scaffolding.md content",
    "archive/{quarter}": "updated quarterly archive content"
  }}
}}
"""

    print("[maintenance] Running context tidying...")
    raw = llm.invoke(tidy_prompt)
    if raw:
        response = llm.parse_response(raw)

        if response.file_updates:
            from .file_updater import apply_updates
            updated = apply_updates(response, notes_folder, data_dir=data_dir)
            print(f"[maintenance] Context tidied: {updated} file(s) updated")

        if response.slack_message:
            # Don't post the full summary to Slack — just a brief note
            clean = response.slack_message.replace("ONBOARDING_COMPLETE", "").strip()
            if clean:
                from .i18n import t
                channel_msg = clean
                # Prepend a header
                if lang == "zh":
                    channel_msg = f"🧹 *每周文件整理完成*\n{clean}"
                else:
                    channel_msg = f"🧹 *Weekly file tidying complete*\n{clean}"
                # We need a channel reference — but we don't have it here
                # The caller will handle posting if needed

    if activity:
        activity.log("maintenance", "Context tidying completed")

    _save_maintenance_state(data_dir, _mark_done(state, "context_tidy"))
    return True


# ─── Run All Maintenance ────────────────────────────────────────

# Maintenance window: 1am - 4am local time
MAINTENANCE_HOUR_START = 1
MAINTENANCE_HOUR_END = 4


def _in_maintenance_window() -> bool:
    """Check if current time is in the maintenance window (1am-4am)."""
    hour = datetime.now().hour
    return MAINTENANCE_HOUR_START <= hour < MAINTENANCE_HOUR_END


def run_maintenance(
    data_dir: str,
    notes_folder: str,
    channel,
    llm,
    config,
    lang: str = "en",
    activity: Optional[ActivityLog] = None,
) -> None:
    """Run all maintenance tasks that are due.

    Called from the main loop on every cycle. Only runs during
    the maintenance window (1am-4am) to avoid interrupting the user.
    Each task checks its own schedule internally and skips if not due.
    """
    if not _in_maintenance_window():
        return

    try:
        check_os_updates(data_dir, notes_folder, activity)
    except Exception as e:
        print(f"[maintenance] OS update check error: {e}")

    try:
        check_ai_cli_updates(data_dir, notes_folder, activity)
    except Exception as e:
        print(f"[maintenance] AI CLI check error: {e}")

    # Memory consolidation and context tidying run together
    try:
        consolidate_memory(data_dir, notes_folder, llm, config, activity)
    except Exception as e:
        print(f"[maintenance] Memory consolidation error: {e}")

    try:
        tidy_context(data_dir, notes_folder, llm, config, lang, activity=activity)
    except Exception as e:
        print(f"[maintenance] Context tidying error: {e}")
