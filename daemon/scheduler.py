"""Cron-like scheduler with day-of-week awareness.

Wraps the `schedule` library with Personal Assistant-specific logic:
weekday-only jobs, staggering, catch-up on restart.
"""

import time
from datetime import datetime, date
from typing import Callable

import schedule


class Scheduler:
    """Schedule operations with day-of-week and time awareness."""

    def __init__(self, timezone: str = "America/New_York"):
        self.timezone = timezone
        self._jobs: list[dict] = []

    def daily(
        self,
        at_time: str,
        job: Callable,
        weekdays_only: bool = True,
        name: str = "",
    ) -> None:
        """Schedule a job to run daily at a specific time.

        Args:
            at_time: Time in HH:MM format (24h).
            job: The function to call.
            weekdays_only: If True, skip weekends.
            name: Human-readable name for logging.
        """
        def wrapped_job():
            today = date.today()
            # Skip weekends if weekdays_only
            if weekdays_only and today.weekday() >= 5:  # 5=Sat, 6=Sun
                print(f"[scheduler] Skipping {name} (weekend)")
                return
            print(f"[scheduler] Running: {name}")
            try:
                job()
            except Exception as e:
                print(f"[scheduler] Error in {name}: {e}")

        schedule.every().day.at(at_time).do(wrapped_job)
        self._jobs.append({
            "name": name,
            "time": at_time,
            "weekdays_only": weekdays_only,
        })
        print(f"[scheduler] Registered: {name} at {at_time}"
              f"{' (weekdays)' if weekdays_only else ''}")

    def weekly(
        self,
        day: str,
        at_time: str,
        job: Callable,
        name: str = "",
    ) -> None:
        """Schedule a job to run weekly on a specific day.

        Args:
            day: Day of week (monday, tuesday, ..., sunday).
            at_time: Time in HH:MM format.
            job: The function to call.
            name: Human-readable name for logging.
        """
        def wrapped_job():
            print(f"[scheduler] Running: {name}")
            try:
                job()
            except Exception as e:
                print(f"[scheduler] Error in {name}: {e}")

        getattr(schedule.every(), day).at(at_time).do(wrapped_job)
        self._jobs.append({
            "name": name,
            "time": at_time,
            "day": day,
        })
        print(f"[scheduler] Registered: {name} on {day} at {at_time}")

    def run_pending(self) -> None:
        """Run any pending scheduled jobs."""
        schedule.run_pending()

    def is_daytime(self, wake_time: str, sleep_time: str) -> bool:
        """Check if current time is within daytime hours.

        Args:
            wake_time: Wake time in HH:MM format.
            sleep_time: Sleep time in HH:MM format.

        Returns:
            True if current time is between wake and sleep times.
        """
        now = datetime.now()
        current = now.hour * 60 + now.minute

        wake_h, wake_m = map(int, wake_time.split(":"))
        sleep_h, sleep_m = map(int, sleep_time.split(":"))
        wake_minutes = wake_h * 60 + wake_m
        sleep_minutes = sleep_h * 60 + sleep_m

        if sleep_minutes > wake_minutes:
            return wake_minutes <= current < sleep_minutes
        else:
            # Crosses midnight
            return current >= wake_minutes or current < sleep_minutes

    def list_jobs(self) -> list[dict]:
        """Return list of registered jobs."""
        return self._jobs
