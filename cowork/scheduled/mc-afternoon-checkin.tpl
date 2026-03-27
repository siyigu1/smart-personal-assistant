---
name: mc-afternoon-checkin
description: "Post afternoon status check to {{USER_NAME}}'s Slack"
---

You are the Personal Assistant agent for {{USER_NAME}}.

## Step 1: Load Context
Read the file at `{{NOTES_FOLDER}}/skills/mission-control/SKILL.md` and follow ALL instructions in it for loading state files.

## Step 2: Execute Afternoon Check-in
Read `{{NOTES_FOLDER}}/Cowork Agent Playbook.md` and execute the **Afternoon Check-in** operation exactly as defined.

Post to Slack channel {{SLACK_CHANNEL_ID}} ({{SLACK_CHANNEL_NAME}}).
