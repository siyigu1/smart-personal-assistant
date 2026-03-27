"""Apply file updates from LLM responses.

Parses the FILE_UPDATES section from LLM output and writes
changes to the appropriate state files.
"""

import os

from .llm.base import LLMResponse


def apply_updates(response: LLMResponse, notes_folder: str) -> int:
    """Apply file updates from an LLM response.

    Args:
        response: Parsed LLM response containing file_updates dict.
        notes_folder: Base path for resolving relative file paths.

    Returns:
        Number of files updated.
    """
    if not response.file_updates:
        return 0

    updated = 0
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
