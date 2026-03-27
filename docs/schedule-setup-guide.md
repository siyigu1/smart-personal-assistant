# Schedule Setup Guide — Claude Desktop

After running `setup.sh`, the scheduled task files are created but you need to configure their timing in Claude Desktop.

## Steps

1. **Open Claude Desktop**
2. **Go to the Schedule tab** (left sidebar)
3. Your tasks should appear automatically (they were created at `~/.claude/scheduled-tasks/`)
4. **Click Edit** on each task to set the schedule

## Recommended Schedules

| Task | Schedule | Hours | Notes |
|------|----------|-------|-------|
| mc-listener | Every 5 minutes | 7am - 9pm | Daytime Slack monitor |
| mc-listener-night | Every 15 minutes | 9pm - 1am | Nighttime, shorter responses |
| mc-morning-dispatch | Daily | Your chosen time | Weekdays only if possible |
| mc-midday-checkin | Daily | Your chosen time | Weekdays only |
| mc-afternoon-checkin | Daily | Your chosen time | Weekdays only |
| mc-eod-summary | Daily | Your chosen time | Weekdays only |
| mc-friday-summary | Weekly | Friday evening | Friday only |
| mc-sunday-planning | Weekly | Sunday evening | Sunday only |

## Tips

- **Listener hours:** Set the daytime listener to only run during waking hours. The night listener handles late hours with gentler responses.
- **Weekend behavior:** The agent respects weekend rules automatically (no deep work suggestions, only during quiet windows). You don't need to disable tasks on weekends — the agent will adjust its behavior.
- **If a task isn't showing up:** Check that the SKILL.md file exists at `~/.claude/scheduled-tasks/<task-name>/SKILL.md`.
- **To temporarily disable a task:** Use the toggle in Claude Desktop, or ask Claude: "pause my morning dispatch task."
- **To modify what a task does:** Edit the SKILL.md file directly — changes take effect on the next run.

## Troubleshooting

**Tasks not appearing in Desktop?**
- Make sure the task directory exists: `ls ~/.claude/scheduled-tasks/`
- Each task needs a `SKILL.md` file inside its directory
- Restart Claude Desktop after creating new tasks

**Agent not posting to Slack?**
- Verify Slack MCP is configured: check `~/.claude/settings.json` for slack server
- Verify channel ID is correct (right-click channel → View channel details → bottom)
- Try running a task manually: start a Claude session and say "Run my morning dispatch"

**Agent reading wrong files?**
- Check the notes folder path in `skills/mission-control/SKILL.md`
- Ensure all state files exist in the notes folder
