# Slack App Setup Guide

## Quick Setup (Recommended)

The `setup.sh` script opens a pre-filled Slack App creation page with all permissions already configured. You just need to:

1. Select your workspace
2. Click **Create**
3. Go to **OAuth & Permissions** → **Install to Workspace** → **Allow**
4. Copy the **Bot User OAuth Token** (starts with `xoxb-`)
5. Create/pick a channel, invite the bot, copy the Channel ID

That's it — 3 steps instead of 7.

## Manual Setup

If you prefer to create the app manually:

### Step 1: Create a Slack App

1. Go to https://api.slack.com/apps
2. Click **Create New App** → **From scratch**
3. App Name: `Personal Assistant` (or `智能管家` for Chinese)
4. Pick your workspace → **Create App**

### Step 2: Add Bot Permissions

1. In the left sidebar, click **OAuth & Permissions**
2. Scroll down to **Bot Token Scopes**
3. Add these scopes:

| Scope | What it does |
|---|---|
| `channels:history` | Read messages in public channels |
| `channels:read` | View basic channel info |
| `chat:write` | Post messages |
| `reactions:read` | See emoji reactions |
| `groups:history` | Read messages in private channels |
| `groups:read` | View private channel info |
| `im:history` | Read direct messages |
| `im:read` | View DM info |
| `im:write` | Send direct messages |

### Step 3: Install to Workspace

1. Click **Install to Workspace** at the top
2. Review permissions → **Allow**

### Step 4: Copy Your Bot Token

1. You'll see **Bot User OAuth Token** (starts with `xoxb-`)
2. Copy this token — keep it secret, don't commit to git

### Step 5: Set Up Channel

1. Create a channel (e.g., `#my-cowork`) or use an existing one
2. Invite the bot: type `/invite @Personal Assistant` in the channel
3. Get Channel ID: right-click channel → View channel details → bottom

## Troubleshooting

**Bot can't post messages?**
- Check that `chat:write` scope is added
- Make sure the bot is invited to the channel
- Verify the channel ID is correct

**Bot can't read messages?**
- Check that `channels:history` scope is added
- For private channels, also add `groups:history`

**Token not working?**
- Make sure you're using the **Bot User OAuth Token**, not the User OAuth Token
- Try reinstalling the app to your workspace
