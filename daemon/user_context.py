"""Per-user context for multi-user daemon.

Each user gets their own channel, notes folder, conversation state,
and short-term memory. The daemon creates one UserContext per user
and polls them all in the same loop.

Daemon internal files (memory, state, automations) live in
data/{user_id}/ inside the repo directory, NOT in the user's
Obsidian folder.
"""

from dataclasses import dataclass
from typing import Optional

from .channels.base import ChannelClient
from .channels.slack import SlackChannel
from .conversation import Conversation
from .reminder_engine import ReminderEngine
from .cross_tasks import CrossTaskChecker
from .config import Config

import os
import re


def _user_id(name: str) -> str:
    """Convert a user name to a safe directory name."""
    return re.sub(r'[^a-zA-Z0-9_-]', '-', name).strip('-').lower() or 'default'


@dataclass
class UserContext:
    """Everything the daemon needs to serve one user."""
    user_name: str
    assistant_name: str
    language: str
    notes_folder: str
    data_dir: str  # data/{user_id}/ for daemon internals
    slack_channel_id: str
    slack_channel_name: str
    channel: ChannelClient
    conversation: Conversation
    reminders: ReminderEngine
    cross_tasks: Optional[CrossTaskChecker] = None


def create_user_contexts(config: Config) -> list[UserContext]:
    """Create UserContext objects for the primary user and any family members.

    Returns a list of UserContext, one per user. The primary user is
    always first.
    """
    contexts = []

    # Cross-tasks path (shared between all users)
    cross_tasks_path = None
    if config.family_name:
        cross_tasks_path = os.path.join(config.data_dir, "cross-tasks.json")

    # Primary user data directory
    primary_user_id = _user_id(config.user_name)
    primary_data_dir = os.path.join(config.data_dir, primary_user_id)
    os.makedirs(primary_data_dir, exist_ok=True)
    os.makedirs(os.path.join(primary_data_dir, "cache"), exist_ok=True)

    # mc-state.json now lives in data dir
    primary_state = os.path.join(primary_data_dir, "mc-state.json")
    primary_channel = SlackChannel(
        bot_token=config.slack_bot_token,
        channel_id=config.slack_channel_id,
        state_file=primary_state,
    )

    primary_cross = None
    if cross_tasks_path:
        primary_cross = CrossTaskChecker(
            cross_tasks_path, config.user_name, config.language
        )

    contexts.append(UserContext(
        user_name=config.user_name,
        assistant_name=config.assistant_name,
        language=config.language,
        notes_folder=config.notes_folder,
        data_dir=primary_data_dir,
        slack_channel_id=config.slack_channel_id,
        slack_channel_name=config.slack_channel_name,
        channel=primary_channel,
        conversation=Conversation(primary_data_dir),
        reminders=ReminderEngine(primary_data_dir),
        cross_tasks=primary_cross,
    ))

    # Family member (if configured)
    if config.family_name and config.family_channel_id and config.family_notes_folder:
        family_user_id = _user_id(config.family_name)
        family_data_dir = os.path.join(config.data_dir, family_user_id)
        os.makedirs(family_data_dir, exist_ok=True)
        os.makedirs(os.path.join(family_data_dir, "cache"), exist_ok=True)

        family_state = os.path.join(family_data_dir, "mc-state.json")

        # Ensure family notes folder exists
        os.makedirs(config.family_notes_folder, exist_ok=True)

        family_channel = SlackChannel(
            bot_token=config.slack_bot_token,  # Same bot, different channel
            channel_id=config.family_channel_id,
            state_file=family_state,
        )

        family_cross = CrossTaskChecker(
            cross_tasks_path, config.family_name, config.language
        ) if cross_tasks_path else None

        # Family member's language defaults to primary user's language
        family_lang = config.language

        # Use family assistant name or derive from primary
        family_assistant = config.assistant_name

        contexts.append(UserContext(
            user_name=config.family_name,
            assistant_name=family_assistant,
            language=family_lang,
            notes_folder=config.family_notes_folder,
            data_dir=family_data_dir,
            slack_channel_id=config.family_channel_id,
            slack_channel_name=f"#{config.family_name.lower()}-cowork",
            channel=family_channel,
            conversation=Conversation(family_data_dir),
            reminders=ReminderEngine(family_data_dir),
            cross_tasks=family_cross,
        ))

    return contexts
