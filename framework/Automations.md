# Automations

> This file controls what your AI assistant does automatically. Each row is an action that runs at a specific time. The AI creates and updates this file based on your preferences during onboarding and ongoing conversations.
>
> **For the AI:** When the user asks to add, change, or remove automated actions (e.g., "check in with me at 3pm", "skip the midday check-in", "remind me to pick up kids every day at 4:30"), update this file accordingly.
>
> **For bot/daemon systems:** Read this file every cycle. For each row where the current time matches, execute the action.

---

## Scheduled Actions

> Actions that run at specific times. The `type` column determines how they're handled:
> - **llm** — Send the prompt to the AI, post the AI's response to the chat channel
> - **message** — Post the message directly to the chat channel (no AI needed, zero tokens)

| Time  | Days      | Type    | Description              | Prompt / Message |
|-------|-----------|---------|--------------------------|------------------|
| _example:_ | | | | |
| 08:00 | weekdays  | llm     | Morning dispatch         | Generate the morning dispatch. Read Workstreams.md, Weekly Goals.md, and Daily Scaffolding.md. Follow the Morning Dispatch template from the Playbook. |
| 12:30 | weekdays  | llm     | Midday check-in          | Generate a midday check-in. Reference today's morning dispatch. Ask about blockers. Keep it short (3-4 lines). |
| 15:30 | weekdays  | llm     | Afternoon check-in       | Generate an afternoon check-in. Suggest what to do in the remaining time. Flag anything at risk. |
| 19:00 | weekdays  | llm     | EOD summary              | Generate the end-of-day summary. Review what got done, what rolled, weekly progress. If Friday, include weekly reflection. |
| 20:00 | sunday    | llm     | Weekly planning          | Run the weekly planning session. Summarize this week, suggest goals for next week. This is a multi-turn conversation. |
| 16:30 | weekdays  | message | Kid pickup reminder      | Reminder: kid pickup in 20 minutes! |

> **Days format:** `daily`, `weekdays`, `weekends`, `monday`, `tuesday`, ..., `sunday`, or comma-separated like `monday,wednesday,friday`
>
> **To disable a row:** Delete it, or change Days to `disabled`
>
> **To add a new action:** Add a row, or tell your AI: "check in with me at 3pm on weekdays"

---

## Notes for AI Agents

When the user asks to modify automations:
- **"Add a check-in at 3pm"** → Add a row: `| 15:00 | weekdays | llm | Afternoon check-in | ... |`
- **"Skip midday check-in"** → Change Days to `disabled` for that row
- **"Remind me to take medicine at 9am every day"** → Add: `| 09:00 | daily | message | Medicine reminder | Reminder: time to take your medicine |`
- **"I don't need the afternoon check-in anymore"** → Remove that row
- **"Can you check in with me twice in the morning?"** → Add a second morning row at the requested time

The `_example:_` row at the top is a placeholder. Remove it once real actions are configured.

---

## Notes for Bot/Daemon Systems

Parsing rules:
1. Read the table under "Scheduled Actions"
2. Skip the header row and any row starting with `_example:_`
3. For each row, check if current time matches `Time` and current day matches `Days`
4. If `Type` is `message`: post `Prompt / Message` directly to the channel
5. If `Type` is `llm`: send `Prompt / Message` as the operation prompt to the LLM, post the response
6. For `weekdays`: Monday-Friday. For `weekends`: Saturday-Sunday. For `daily`: every day.
7. Track which actions have fired today to avoid duplicates (use a tolerance window, e.g., action fires if current time is within 5 minutes of the scheduled time)
