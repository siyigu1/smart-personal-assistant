#!/usr/bin/env bash
# English language strings

# Banner
MSG_BANNER_TITLE="Smart Personal Assistant"
MSG_BANNER_SUBTITLE="AI-powered personal life management system"

# Existing setup
MSG_EXISTING_FOUND="Existing Setup Found"
MSG_EXISTING_LOADING="Loading previous setup..."
MSG_EXISTING_START_FRESH="Start fresh"

# System check
MSG_SYSTEM_CHECK="System Check"
MSG_PYTHON_NOT_FOUND="Python 3 not found"
MSG_PIP_AVAILABLE="pip available"
MSG_PIP_NOT_FOUND="pip not found — you'll need it to install dependencies"
MSG_CLAUDE_NOT_FOUND="Claude CLI not found"
MSG_CONTINUE_WITHOUT="Continue without Claude CLI?"

# Mode
MSG_MODE_TITLE="Setup Mode"
MSG_MODE_DAEMON="Daemon mode (recommended) — ~15-20K tokens/day"
MSG_MODE_COWORK="Cowork mode — ~60-80K tokens/day"

# Identity
MSG_IDENTITY_TITLE="Who Are You?"
MSG_IDENTITY_NAME="How should I call you?"
MSG_IDENTITY_ASSISTANT="Name your assistant:"

# LLM
MSG_LLM_TITLE="LLM Provider"
MSG_LLM_CLAUDE="Claude (Anthropic) — uses Pro/Max subscription via CLI (recommended)"
MSG_LLM_OLLAMA="Ollama — free, runs locally (coming soon)"
MSG_LLM_CUSTOM="Custom — any OpenAI-compatible API (coming soon)"

# Channel
MSG_CHANNEL_TITLE="Chat Channel"
MSG_CHANNEL_CURRENT="Current Slack configuration:"
MSG_CHANNEL_CHANGE="Change Slack configuration?"
MSG_CHANNEL_KEEPING="Keeping existing Slack configuration"
MSG_CHANNEL_SLACK="Slack (recommended)"
MSG_CHANNEL_DISCORD="Discord (coming soon)"
MSG_CHANNEL_TELEGRAM="Telegram (coming soon)"

# Slack setup
MSG_SLACK_TITLE="Slack App Setup"
MSG_SLACK_STEP1="Step 1/3: Create the Slack App"
MSG_SLACK_OPEN_AUTO="Opening Slack with all permissions pre-filled..."
MSG_SLACK_SELECT_AUTO="Select your workspace → Next → Create"
MSG_SLACK_FALLBACK="If Slack shows an error, choose 'From an app manifest' instead,"
MSG_SLACK_FALLBACK2="switch to JSON tab, and paste the contents of:"
MSG_SLACK_OPEN_MANUAL="Opening Slack app creation page..."
MSG_SLACK_MANUAL_MANIFEST="Choose 'From an app manifest' → select workspace → Next"
MSG_SLACK_MANUAL_JSON="Switch to 'JSON' tab, paste contents of:"
MSG_SLACK_MANUAL_CREATE="Click Next → Create"
MSG_SLACK_STEP2="Step 2/3: Install & Copy Token"
MSG_SLACK_INSTALL="Go to 'OAuth & Permissions' in the left sidebar"
MSG_SLACK_INSTALL2="Click 'Install to Workspace' → 'Allow'"
MSG_SLACK_INSTALL3="Copy the 'Bot User OAuth Token' (starts with xoxb-)"
MSG_SLACK_PASTE="Paste your Bot Token:"
MSG_SLACK_TOKEN_WARN="Token doesn't start with 'xoxb-' — make sure you copied the Bot token, not the User token"
MSG_SLACK_STEP3="Step 3/3: Set Up Channel"
MSG_SLACK_CHANNEL_CREATE="Create a channel (e.g., #my-cowork) or use an existing one"
MSG_SLACK_CHANNEL_INVITE="Invite the bot:"
MSG_SLACK_CHANNEL_ID_HINT="Get Channel ID: right-click channel → View details → bottom"
MSG_SLACK_CHANNEL_ID="Channel ID (starts with C):"
MSG_SLACK_CHANNEL_NAME="Channel name:"
MSG_SLACK_DONE="Slack configured!"

# Slack test
MSG_SLACK_TEST="Test Slack connection?"
MSG_SLACK_TEST_SENDING="Sending test message..."
MSG_SLACK_TEST_OK="Test message sent! Check your channel."
MSG_SLACK_TEST_FAIL="Could not send message."
MSG_SLACK_TEST_DEBUG="Troubleshooting:"
MSG_SLACK_TEST_DEBUG1="1. Is the app installed to your workspace? (OAuth & Permissions → Install)"
MSG_SLACK_TEST_DEBUG2="2. Is the Bot Token correct? (should start with xoxb-)"
MSG_SLACK_TEST_DEBUG3="3. Are the bot scopes added? (channels:history, chat:write, etc.)"
MSG_SLACK_TEST_DEBUG4="4. Is the Channel ID correct? (right-click channel → View details)"
MSG_SLACK_TEST_DEBUG5="5. Is the bot invited to the channel? (/invite @bot-name)"
MSG_SLACK_TEST_RETRY="Fix the issue and try again?"
MSG_SLACK_TEST_MSG="Hello! Your Personal Assistant is connected and ready."

# Slack cowork
MSG_SLACK_COWORK="For Cowork mode, Claude uses Slack MCP (built-in)."
MSG_SLACK_COWORK2="You just need your channel info."

# Profile
MSG_PROFILE_TITLE="Storage & Timezone"
MSG_PROFILE_TIMEZONE="Timezone:"
MSG_PROFILE_FOLDER="Where should your files be stored?"
MSG_PROFILE_FOLDER_HINT="Using a cloud folder enables mobile access (Obsidian) and family sharing."
MSG_PROFILE_FOLDER_CURRENT="Notes folder:"
MSG_PROFILE_ICLOUD="iCloud (Obsidian vault) — best for mobile + family sharing"
MSG_PROFILE_ICLOUD_DOCS="iCloud Documents — syncs across Apple devices"
MSG_PROFILE_DROPBOX="Dropbox — cross-platform sync"
MSG_PROFILE_GDRIVE="Google Drive — cross-platform sync"
MSG_PROFILE_ONEDRIVE="OneDrive — cross-platform sync"
MSG_PROFILE_LOCAL="Local only — ~/Documents/Personal Assistant"
MSG_PROFILE_CUSTOM="Custom path"
MSG_PROFILE_ENTER_PATH="Enter full path:"

# Family
MSG_FAMILY_TITLE="Family Extension (Optional)"
MSG_FAMILY_CURRENT="Current family setup:"
MSG_FAMILY_CHANGE="Change family configuration?"
MSG_FAMILY_KEEPING="Keeping existing family setup"
MSG_FAMILY_CONFIRM="Set up a second user (spouse/partner)?"
MSG_FAMILY_NAME="Their name:"
MSG_FAMILY_CHANNEL="Their Slack channel ID:"
MSG_FAMILY_CHANNEL_NAME="Their channel name:"
MSG_FAMILY_FOLDER="Their notes folder:"

# File generation
MSG_GENERATING="Generating Files"
MSG_ALREADY_EXISTS="already exists — skipping"
MSG_FRAMEWORK_DONE="Framework files in:"
MSG_FRAMEWORK_HINT="Your schedule and workstreams will be set up conversationally when the AI connects."

# Dependencies
MSG_DEPS_TITLE="Installing Dependencies"
MSG_DEPS_VENV="Virtual environment: .venv/"
MSG_DEPS_INSTALLED="Python dependencies installed"
MSG_DEPS_FAIL="Could not install automatically. Run manually:"
MSG_DEPS_ENV=".env updated (bot token stored)"

# Daemon
MSG_DAEMON_TITLE="Start Daemon"
MSG_DAEMON_BG="Background service (auto-starts on boot)"
MSG_DAEMON_MANUAL="Manual (run ./run.sh yourself)"
MSG_DAEMON_VERIFY="Verifying daemon is running..."
MSG_DAEMON_RUNNING="Daemon is running"
MSG_DAEMON_NOT_RUNNING="Daemon may not have started. Check logs:"
MSG_DAEMON_MANUAL_START="To start manually:"
MSG_DAEMON_MANUAL_VERIFY="To verify it's working:"
MSG_DAEMON_ALREADY_RUNNING="A daemon is already running."
MSG_DAEMON_RESTART_PROMPT="What would you like to do?"
MSG_DAEMON_RESTART_OPT1="Restart automatically (update config & restart)"
MSG_DAEMON_RESTART_OPT2="Stop only (I'll start it manually later)"
MSG_DAEMON_STOPPING="Stopping existing daemon..."
MSG_DAEMON_STOPPED="Daemon stopped"
MSG_DAEMON_RESTARTING="Restarting daemon with updated config..."
MSG_DAEMON_MANUAL_REMINDER="Daemon has been stopped. To start it manually:"
MSG_DAEMON_FDA_TITLE="iCloud Notes Folder Detected"
MSG_DAEMON_FDA_EXPLAIN="macOS blocks background services (launchd) from accessing iCloud files. Since your notes are in iCloud, the daemon must run from Terminal instead."
MSG_DAEMON_FDA_MANUAL="To start the daemon, run this in Terminal:"
MSG_DAEMON_FDA_TIP="Tip: add this command to your shell profile (~/.zshrc) to start it automatically on login."

# Summary
MSG_SUMMARY_COMPLETE="Setup Complete!"
MSG_SUMMARY_NEXT="What happens next:"
MSG_SUMMARY_NEXT1="The daemon checks Slack every minute"
MSG_SUMMARY_NEXT2="On first run, the AI will message you in"
MSG_SUMMARY_NEXT3="to learn about your schedule and projects (~15 min chat)"
MSG_SUMMARY_NEXT4="After onboarding, it runs on autopilot — dispatches,"
MSG_SUMMARY_NEXT5="check-ins, reminders, all automatic"
MSG_SUMMARY_COMMANDS="Useful commands:"
MSG_SUMMARY_LOG="Setup log saved to:"
MSG_SUMMARY_LOG_HINT="If you run into issues, attach this log to your GitHub issue."
MSG_SUMMARY_ENJOY="Enjoy your AI-powered life management system!"

# Common
MSG_DONE="Done?"
MSG_CHOICE="Choice:"

# Run script
MSG_RUN_STARTING="Starting Personal Assistant daemon..."
MSG_RUN_LOG="Log file:"
MSG_RUN_CREATING_VENV="Creating virtual environment..."
MSG_RUN_INSTALLING="Installing dependencies..."
MSG_RUN_MISSING="Missing Python dependencies:"
MSG_RUN_INSTALLING_MISSING="Installing missing dependencies:"
