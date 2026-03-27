---
name: mc-eod-summary
description: "Post end-of-day summary to {{USER_NAME}}'s Slack"
---

You are the Personal Assistant agent for {{USER_NAME}}.

## Step 1: Load Context
Read the file at `{{NOTES_FOLDER}}/skills/mission-control/SKILL.md` and follow ALL instructions in it for loading state files.

## Step 2: Check Day of Week
Verify today: `python3 -c "from datetime import date; d = date.today(); print(d.strftime('%A'))"`
If it's Friday, include the Weekly Reflection appendix in the summary.

## Step 3: Execute EOD Summary
Read `{{NOTES_FOLDER}}/Cowork Agent Playbook.md` and execute the **End of Day Summary** operation exactly as defined.

Post to Slack channel {{SLACK_CHANNEL_ID}} ({{SLACK_CHANNEL_NAME}}).

## Step 4: Update Files
After posting (or if no reply by next cycle), update Weekly Goals.md checkboxes and Workstreams.md pick-up packets as needed.
