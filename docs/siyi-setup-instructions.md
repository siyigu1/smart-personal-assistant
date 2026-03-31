# Setup Instructions for Siyi's Computer

> Give this file to Claude on your other computer. It has everything needed to set up the smart-personal-assistant daemon with your existing Mission Control data.

---

## Step 1: Clone the repo

```bash
git clone https://github.com/siyigu1/smart-personal-assistant.git
cd smart-personal-assistant
```

## Step 2: Run setup

```bash
./setup.sh
```

When prompted, enter these values:

| Prompt | Answer |
|--------|--------|
| Language | 1 (English) |
| How should I call you? | Siyi |
| Name your assistant | Assistant |
| Setup Mode | 1 (Daemon) |
| LLM Provider | 1 (Claude) |
| Slack channel/token | Use your existing Slack channel ID and bot token (you'll need to enter them during setup) |
| Notes folder | Point to your existing Mission Control folder in iCloud Obsidian: `/Users/YOUR_USERNAME/Library/Mobile Documents/iCloud~md~obsidian/Documents/Mission Control` |
| Family extension | No (skip for now — multi-user support needs to be added to the daemon first) |
| Start daemon | 1 (Background service) |
| Test Slack | Yes — verify the test message appears in your channel |

**Important:** When asked for the notes folder, choose the path to your EXISTING Mission Control folder. The setup will copy framework files there but will NOT overwrite your existing Workstreams.md, Weekly Goals.md, Daily Scaffolding.md, etc. — those are skipped because they already exist.

## Step 3: Verify

After setup completes:

```bash
# Check status
./status.sh

# Check your Slack channel — you should see a test message

# Check that your existing files are intact
ls "/path/to/your/Mission Control/"
# Should see your existing Workstreams.md, Weekly Goals.md, etc.
# Plus new framework files: START HERE.md, Getting Started.md, Automations.md, etc.
```

## Step 4: Create Automations.md

Your existing Mission Control doesn't have an Automations.md. The daemon reads this file to know what scheduled tasks to run. Create it based on your current setup:

Open the `Automations.md` that was copied to your notes folder and edit it. Replace the example rows with your actual schedule:

```markdown
# Automations

| Time  | Days      | Type    | Description              | Prompt / Message |
|-------|-----------|---------|--------------------------|------------------|
| 08:00 | weekdays  | llm     | Morning dispatch         | Generate the morning dispatch. Read Workstreams.md, Weekly Goals.md, and Daily Scaffolding.md. Follow the Morning Dispatch template from the Playbook. |
| 12:30 | weekdays  | llm     | Midday check-in          | Generate a midday check-in. Reference today's morning dispatch. Ask about blockers. Keep it short. |
| 15:30 | weekdays  | llm     | Afternoon check-in       | Generate an afternoon check-in. Suggest what to do in the remaining time. Flag anything at risk. |
| 19:00 | weekdays  | llm     | EOD summary              | Generate the end-of-day summary. Review what got done, what rolled, weekly progress. If Friday, include weekly reflection. |
| 20:00 | sunday    | llm     | Weekly planning          | Run the weekly planning session. Summarize this week, suggest goals for next week. |
| 16:30 | weekdays  | message | Kid pickup reminder      | Reminder: kid pickup in 20 minutes! |
```

Adjust times and add/remove rows to match your preferences.

## Step 5: Ongoing usage

The daemon is now running as a background service. It will:

- Poll your Slack channel every 60 seconds
- Fire reminders from reminders.json
- Run scheduled automations from Automations.md
- Respond to your messages using Claude CLI

**Useful commands:**

```bash
cd /path/to/smart-personal-assistant

./status.sh              # Check daemon status + recent activity
./status.sh activity     # Recent activity log
./status.sh llm          # Recent LLM calls
./status.sh errors       # Recent errors

./run.sh --once          # Test one cycle manually

# View logs
tail -f ~/.mission-control.log

# Restart after changes
launchctl stop com.mission-control.daemon
launchctl start com.mission-control.daemon

# Re-run setup (preserves your data)
./setup.sh
```

## Notes

- Your existing Mission Control files (Workstreams.md, Weekly Goals.md, Daily Scaffolding.md, Grocery List.md, Travel Master List.md, reminders.json) are used as-is — the daemon reads them every cycle
- The daemon won't trigger onboarding since your Workstreams.md already has real content (no placeholder text)
- The Cowork Agent Playbook.md and SKILL.md in your folder may be overwritten by the setup — that's fine, the daemon uses START HERE.md as the system prompt
- If the daemon can't reach Claude CLI (auth expired etc.), it posts a notification to your Slack channel
