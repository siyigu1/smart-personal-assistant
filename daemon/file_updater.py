"""Apply file updates from LLM responses.

Handles the 'files' dict from LLM JSON output. Keys map to
markdown files in the user's notes folder.

Automations are handled separately via add/update/remove_automations
in the automations module — not through file_updater.
"""

import os

from .llm.base import LLMResponse


def apply_updates(response: LLMResponse, notes_folder: str, data_dir: str = "") -> int:
    """Apply file updates from an LLM response.

    Also applies automation mutations (add/update/remove) if present.

    Args:
        response: Parsed LLM response containing file_updates dict.
        notes_folder: Base path for resolving relative file paths.
        data_dir: Path to data/{user_id}/ for daemon internal files.

    Returns:
        Number of files updated.
    """
    updated = 0

    # Handle automation mutations
    if data_dir:
        from .automations import add_automations, update_automations, remove_automations
        if response.add_automations:
            add_automations(data_dir, notes_folder, response.add_automations)
            updated += 1
        if response.update_automations:
            update_automations(data_dir, notes_folder, response.update_automations)
            updated += 1
        if response.remove_automations:
            remove_automations(data_dir, notes_folder, response.remove_automations)
            updated += 1

    if not response.file_updates:
        return updated

    for path, content in response.file_updates.items():
        # Resolve relative paths against notes folder
        if not os.path.isabs(path):
            path = os.path.join(notes_folder, path)

        # Safety check: only write to files within the notes folder
        real_path = os.path.realpath(path)
        real_notes = os.path.realpath(notes_folder)
        if not real_path.startswith(real_notes):
            print(f"[file_updater] Skipping path outside notes folder: {path}")
            continue

        try:
            os.makedirs(os.path.dirname(path), exist_ok=True)
            with open(path, "w") as f:
                f.write(content)
            updated += 1
            print(f"[file_updater] Updated: {os.path.basename(path)}")
        except OSError as e:
            print(f"[file_updater] Error writing {path}: {e}")

    return updated
