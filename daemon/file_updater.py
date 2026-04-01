"""Apply file updates from LLM responses.

Handles the 'files' dict from LLM JSON output. Most keys map to
markdown files in the user's notes folder. The special 'automations'
key (when it's an array) is routed to the automations system.
"""

import os

from .llm.base import LLMResponse


def apply_updates(response: LLMResponse, notes_folder: str, data_dir: str = "") -> int:
    """Apply file updates from an LLM response.

    Args:
        response: Parsed LLM response containing file_updates dict.
        notes_folder: Base path for resolving relative file paths.
        data_dir: Path to data/{user_id}/ for daemon internal files.

    Returns:
        Number of files updated.
    """
    if not response.file_updates:
        return 0

    updated = 0
    for path, content in response.file_updates.items():
        # Special handling: automations as array → write both JSON and MD
        if path == "automations" and isinstance(content, list):
            if data_dir:
                from .automations import write_automations
                write_automations(data_dir, notes_folder, content)
                updated += 1
            else:
                print("[file_updater] Skipping automations: no data_dir provided")
            continue

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
