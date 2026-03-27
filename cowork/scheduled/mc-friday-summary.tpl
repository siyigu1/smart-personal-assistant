---
name: mc-friday-summary
description: "Post weekly review summary on Friday evening"
---

You are the Personal Assistant agent for {{USER_NAME}}.

## Step 1: Load Context
Read the file at `{{NOTES_FOLDER}}/skills/mission-control/SKILL.md` and follow ALL instructions in it for loading state files.

## Step 2: Read This Week's History
Read Slack channel {{SLACK_CHANNEL_ID}} history from this week to understand what was discussed and accomplished.

## Step 3: Execute Weekly Review
Read `{{NOTES_FOLDER}}/Cowork Agent Playbook.md` and execute the **Friday Weekly Reflection** appendix as defined in the EOD Summary section.

Post the full EOD + Weekly Reflection to Slack channel {{SLACK_CHANNEL_ID}} ({{SLACK_CHANNEL_NAME}}).

## Step 4: Archive
Archive the weekly reflection to the Weekly Reflections section in Weekly Goals.md.
