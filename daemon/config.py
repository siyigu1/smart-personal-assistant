"""Configuration loader for Mission Control daemon."""

import json
import os
from dataclasses import dataclass, field
from typing import Optional

from dotenv import load_dotenv


@dataclass
class Features:
    dispatch: bool = True
    midday: bool = True
    afternoon: bool = True
    eod: bool = True
    weekly_review: bool = True
    weekly_plan: bool = True
    grocery: bool = False
    travel: bool = False
    family: bool = False


@dataclass
class Config:
    user_name: str = "User"
    slack_bot_token: str = ""
    slack_channel_id: str = ""
    slack_channel_name: str = ""
    timezone: str = "America/New_York"
    notes_folder: str = ""
    language: str = "en"
    llm_provider: str = "claude-cli"
    channel_provider: str = "slack"

    wake_time: str = "07:30"
    sleep_time: str = "23:00"
    work_start: str = "09:00"
    work_end: str = "17:00"

    dispatch_time: str = "08:00"
    midday_time: str = "12:30"
    afternoon_time: str = "15:30"
    eod_time: str = "19:00"
    weekly_plan_time: str = "20:00"

    features: Features = field(default_factory=Features)

    # Family extension
    family_name: str = ""
    family_channel_id: str = ""
    family_notes_folder: str = ""


def load_config(config_path: Optional[str] = None) -> Config:
    """Load configuration from .mc-config.json and .env files.

    Args:
        config_path: Path to .mc-config.json. If None, uses MC_CONFIG
                     environment variable or searches common locations.
    """
    # Load .env for secrets (Slack bot token, etc.)
    load_dotenv()

    # Find config file
    if config_path is None:
        config_path = os.environ.get("MC_CONFIG")

    if config_path is None:
        # Search common locations
        candidates = [
            os.path.expanduser("~/Documents/Mission Control/.mc-config.json"),
            os.path.expanduser("~/Documents/mission-control/.mc-config.json"),
        ]
        for c in candidates:
            if os.path.exists(c):
                config_path = c
                break

    if config_path is None or not os.path.exists(config_path):
        print("[config] No .mc-config.json found. Run setup.sh first.")
        raise FileNotFoundError("No .mc-config.json found")

    with open(config_path) as f:
        data = json.load(f)

    features_data = data.get("features", {})
    features = Features(
        dispatch=features_data.get("dispatch", True),
        midday=features_data.get("midday", True),
        afternoon=features_data.get("afternoon", True),
        eod=features_data.get("eod", True),
        weekly_review=features_data.get("weekly_review", True),
        weekly_plan=features_data.get("weekly_plan", True),
        grocery=features_data.get("grocery", False),
        travel=features_data.get("travel", False),
        family=features_data.get("family", False),
    )

    config = Config(
        user_name=data.get("user_name", "User"),
        slack_bot_token=os.environ.get("SLACK_BOT_TOKEN", ""),
        slack_channel_id=data.get("slack_channel_id", ""),
        slack_channel_name=data.get("slack_channel_name", ""),
        timezone=data.get("timezone", "America/New_York"),
        notes_folder=data.get("notes_folder", ""),
        language=data.get("language", "en"),
        llm_provider=data.get("llm_provider", "claude-cli"),
        channel_provider=data.get("channel_provider", "slack"),
        wake_time=data.get("wake_time", "07:30"),
        sleep_time=data.get("sleep_time", "23:00"),
        work_start=data.get("work_start", "09:00"),
        work_end=data.get("work_end", "17:00"),
        dispatch_time=data.get("dispatch_time", "08:00"),
        midday_time=data.get("midday_time", "12:30"),
        afternoon_time=data.get("afternoon_time", "15:30"),
        eod_time=data.get("eod_time", "19:00"),
        weekly_plan_time=data.get("weekly_plan_time", "20:00"),
        features=features,
        family_name=data.get("family_name", ""),
        family_channel_id=data.get("family_channel_id", ""),
        family_notes_folder=data.get("family_notes_folder", ""),
    )

    if not config.slack_bot_token:
        print("[config] Warning: SLACK_BOT_TOKEN not set in .env")

    return config
