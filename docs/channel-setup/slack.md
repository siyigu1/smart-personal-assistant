# Slack App Setup Guide

Step-by-step guide to create a Slack App for Mission Control.

## Step 1: Create a Slack App

1. Go to https://api.slack.com/apps
2. Click **Create New App**
3. Choose **From scratch**
4. App Name: `Mission Control` (or whatever you like)
5. Pick your workspace
6. Click **Create App**

## Step 2: Add Bot Permissions

1. In the left sidebar, click **OAuth & Permissions**
2. Scroll down to **Bot Token Scopes**
3. Click **Add an OAuth Scope** and add these scopes:

| Scope | What it does |
|---|---|
| `channels:history` | Read messages in public channels |
| `channels:read` | View basic channel info |
| `chat:write` | Post messages |
| `reactions:read` | See emoji reactions |

## Step 3: Install to Workspace

1. Scroll back to the top of the **OAuth & Permissions** page
2. Click **Install to Workspace**
3. Review the permissions and click **Allow**

## Step 4: Copy Your Bot Token

1. After installation, you'll see **Bot User OAuth Token**
2. It starts with `xoxb-`
3. Copy this token — you'll need it for the setup script
4. Keep it secret! Don't commit it to git.

## Step 5: Create a Channel

1. In Slack, create a new channel (e.g., `#my-cowork`)
2. Or use an existing channel

## Step 6: Add the Bot to Your Channel

1. Go to the channel
2. Type `/invite @Mission Control` (use whatever name you chose)
3. The bot should appear as a member

## Step 7: Get the Channel ID

1. Right-click the channel name in the sidebar
2. Click **View channel details**
3. Scroll to the bottom
4. Copy the **Channel ID** (starts with `C`)

## Troubleshooting

**Bot can't post messages?**
- Check that `chat:write` scope is added
- Make sure the bot is invited to the channel
- Verify the channel ID is correct

**Bot can't read messages?**
- Check that `channels:history` scope is added
- Make sure it's a public channel, or add `groups:history` for private channels

**Token not working?**
- Make sure you're using the **Bot User OAuth Token**, not the User OAuth Token
- Try reinstalling the app to your workspace
