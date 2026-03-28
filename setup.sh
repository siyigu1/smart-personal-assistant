#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
VERSION="2.0.0"
UPDATE_MODE=false
SETUP_MODE="daemon"  # daemon or cowork

# ─── Colors & Helpers ───────────────────────────────────────────────

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m'
BOLD='\033[1m'
DIM='\033[2m'

print_success()  { echo -e "  ${GREEN}✓${NC} $1"; }
print_warning()  { echo -e "  ${YELLOW}!${NC} $1"; }
print_error()    { echo -e "  ${RED}✗${NC} $1"; }
print_step()     { echo -e "\n${BLUE}━━━${NC} ${BOLD}$1${NC} ${BLUE}━━━${NC}\n"; }

ask() {
    local prompt="$1" var="$2"
    read -rp "$(echo -e "  ${BOLD}$prompt${NC} ")" "$var"
}

ask_default() {
    local prompt="$1" default="$2" var="$3"
    read -rp "$(echo -e "  ${BOLD}$prompt${NC} ${DIM}[$default]${NC} ")" "$var"
    if [[ -z "${!var}" ]]; then
        eval "$var='$default'"
    fi
}

confirm() {
    local ans
    read -rp "$(echo -e "  ${BOLD}$1${NC} ${DIM}[Y/n]${NC} ")" ans
    [[ -z "$ans" || "$ans" =~ ^[Yy] ]]
}

open_url() {
    local url="$1"
    echo -e "  ${DIM}→ $url${NC}"
    if [[ "$(uname)" == "Darwin" ]]; then
        open "$url" 2>/dev/null || true
    elif command -v xdg-open &>/dev/null; then
        xdg-open "$url" 2>/dev/null || true
    fi
}

# Cross-platform sed -i
do_sed() {
    if [[ "$(uname)" == "Darwin" ]]; then
        sed -i '' "$@"
    else
        sed -i "$@"
    fi
}

# ─── Banner ─────────────────────────────────────────────────────────

show_banner() {
    echo ""
    echo -e "${BOLD}╔═══════════════════════════════════════════════════╗${NC}"
    echo -e "${BOLD}║   Smart Personal Assistant                      ║${NC}"
    echo -e "${BOLD}║   v${VERSION}                                            ║${NC}"
    echo -e "${BOLD}║                                                   ║${NC}"
    echo -e "${BOLD}║   AI-powered personal life management system      ║${NC}"
    echo -e "${BOLD}╚═══════════════════════════════════════════════════╝${NC}"
    echo ""
}

# ─── Parse CLI Args ─────────────────────────────────────────────────

parse_args() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            --mode)
                SETUP_MODE="$2"
                shift 2
                ;;
            --quick)
                QUICK_MODE=true
                shift
                ;;
            *)
                shift
                ;;
        esac
    done
}

QUICK_MODE=false

# ─── Step 1: System Check ───────────────────────────────────────────

check_system() {
    print_step "Step 1: System Check"

    # Python
    if command -v python3 &>/dev/null; then
        local pyver
        pyver=$(python3 --version 2>&1 | awk '{print $2}')
        print_success "Python $pyver"
    else
        print_error "Python 3 not found"
        echo "    Install Python 3.10+: https://www.python.org/downloads/"
        exit 1
    fi

    # pip
    if python3 -m pip --version &>/dev/null 2>&1; then
        print_success "pip available"
    else
        print_warning "pip not found — you'll need it to install dependencies"
    fi

    # Claude CLI (for daemon mode)
    if [[ "$SETUP_MODE" == "daemon" ]]; then
        if command -v claude &>/dev/null; then
            local clver
            clver=$(claude --version 2>/dev/null || echo "unknown")
            print_success "Claude CLI ($clver)"
        else
            print_warning "Claude CLI not found"
            echo "    Required for daemon mode. Install:"
            open_url "https://docs.anthropic.com/en/docs/claude-code"
            if ! confirm "Continue without Claude CLI?"; then
                exit 1
            fi
        fi
    fi
}

# ─── Step 2: Setup Mode ─────────────────────────────────────────────

collect_mode() {
    if [[ "$SETUP_MODE" != "daemon" && "$SETUP_MODE" != "cowork" ]]; then
        print_step "Step 2: Setup Mode"

        echo "  How would you like to run Personal Assistant?"
        echo ""
        echo "    1. ${BOLD}Daemon mode${NC} (recommended)"
        echo "       A lightweight Python script runs in the background."
        echo "       Handles polling + reminders with zero AI tokens."
        echo "       Only calls the AI when intelligence is needed."
        echo "       Token usage: ~15-20K/day"
        echo ""
        echo "    2. ${BOLD}Cowork mode${NC}"
        echo "       Everything runs through Claude Desktop scheduled tasks."
        echo "       Simpler setup, but uses more tokens."
        echo "       Token usage: ~60-80K/day"
        echo ""

        ask_default "Choice:" "1" mode_choice
        if [[ "$mode_choice" == "2" ]]; then
            SETUP_MODE="cowork"
        else
            SETUP_MODE="daemon"
        fi
    fi

    print_success "Mode: $SETUP_MODE"
}

# ─── Step 3: Language ────────────────────────────────────────────────

collect_language() {
    print_step "Step 3: Language / 语言"

    echo "    1. English"
    echo "    2. 中文"

    ask_default "Choice:" "1" lang_choice

    if [[ "$lang_choice" == "2" ]]; then
        LANG_CODE="zh"
        print_success "语言：中文"
    else
        LANG_CODE="en"
        print_success "Language: English"
    fi
}

# ─── Step 4: LLM Provider ───────────────────────────────────────────

LLM_PROVIDER="claude-cli"

collect_llm() {
    if [[ "$SETUP_MODE" == "cowork" ]]; then
        LLM_PROVIDER="claude-desktop"
        return
    fi

    print_step "Step 4: LLM Provider"

    echo "    1. Claude (Anthropic) — uses Pro/Max subscription via CLI (recommended)"
    echo "    2. Ollama — free, runs locally (coming soon)"
    echo "    3. Custom — any OpenAI-compatible API (coming soon)"

    ask_default "Choice:" "1" llm_choice
    LLM_PROVIDER="claude-cli"

    # Validate Claude CLI connection
    if command -v claude &>/dev/null; then
        print_success "Claude CLI is available"
    fi
}

# ─── Step 5: Chat Channel ───────────────────────────────────────────

SLACK_BOT_TOKEN=""

collect_channel() {
    print_step "Step 5: Chat Channel"

    echo "    1. Slack (recommended)"
    echo "    2. Discord (coming soon)"
    echo "    3. Telegram (coming soon)"

    ask_default "Choice:" "1" channel_choice
    CHANNEL_PROVIDER="slack"

    if [[ "$SETUP_MODE" == "daemon" ]]; then
        setup_slack_app
    else
        setup_slack_cowork
    fi
}

setup_slack_app() {
    echo ""
    echo -e "  ${BOLD}━━━ Slack App Setup ━━━${NC}"
    echo ""
    echo "  Let's create a Slack App with all permissions pre-filled."
    echo ""

    # Determine app name based on language
    local app_name="Personal Assistant"
    if [[ "$LANG_CODE" == "zh" ]]; then
        app_name="智能管家"
    fi

    # Build the manifest JSON
    local manifest
    manifest=$(cat <<MANIFEST
{
  "display_information": {
    "name": "${app_name}",
    "description": "AI-powered personal life management assistant",
    "background_color": "#2c2d30"
  },
  "features": {
    "bot_user": {
      "display_name": "${app_name}",
      "always_online": true
    }
  },
  "oauth_config": {
    "scopes": {
      "bot": [
        "channels:history",
        "channels:read",
        "chat:write",
        "reactions:read",
        "groups:history",
        "groups:read",
        "im:history",
        "im:read",
        "im:write"
      ]
    }
  },
  "settings": {
    "org_deploy_enabled": false,
    "socket_mode_enabled": false,
    "token_rotation_enabled": false
  }
}
MANIFEST
)

    # URL-encode the manifest for the creation URL
    local encoded_manifest
    encoded_manifest=$(python3 -c "import urllib.parse, sys; print(urllib.parse.quote(sys.stdin.read()))" <<< "$manifest")

    # Step 1: Create App from manifest
    echo -e "  ${BOLD}Step 1/3: Create the Slack App${NC}"
    echo "    → Opening Slack with all permissions pre-filled..."
    echo "    → Just select your workspace and click 'Create'"
    open_url "https://api.slack.com/apps?new_app=1&manifest_json=${encoded_manifest}"
    echo ""
    confirm "Done?" || true

    # Step 2: Install + Copy Token
    echo ""
    echo -e "  ${BOLD}Step 2/3: Install & Copy Token${NC}"
    echo "    → Go to 'OAuth & Permissions' in the left sidebar"
    echo "    → Click 'Install to Workspace' → 'Allow'"
    echo "    → Copy the 'Bot User OAuth Token' (starts with xoxb-)"
    echo ""
    ask "Paste your Bot Token:" SLACK_BOT_TOKEN

    if [[ ! "$SLACK_BOT_TOKEN" =~ ^xoxb- ]]; then
        print_warning "Token doesn't start with 'xoxb-' — make sure you copied the Bot token, not the User token"
    fi

    # Step 3: Channel
    echo ""
    echo -e "  ${BOLD}Step 3/3: Set Up Channel${NC}"
    echo "    → Create a channel in Slack (e.g., #my-cowork) or use an existing one"
    echo "    → Invite the bot: type /invite @${app_name} in the channel"
    echo "    → Get the Channel ID:"
    echo "      Right-click channel name → View channel details → scroll to bottom"
    echo ""
    ask "Channel ID (starts with C):" SLACK_CHANNEL_ID
    ask_default "Channel name:" "#my-cowork" SLACK_CHANNEL_NAME

    echo ""
    print_success "Slack configured!"
}

setup_slack_cowork() {
    echo ""
    echo "  For Cowork mode, Claude uses Slack MCP (built-in)."
    echo "  You just need your channel info."
    echo ""
    echo "  To find your Channel ID:"
    echo "    Right-click channel → View channel details → scroll to bottom"
    echo ""
    ask "Slack Channel ID (starts with C):" SLACK_CHANNEL_ID
    ask_default "Slack channel name:" "#my-cowork" SLACK_CHANNEL_NAME
    CHANNEL_PROVIDER="slack"
}

# ─── Step 6: User Profile ───────────────────────────────────────────

collect_profile() {
    print_step "Step 6: User Profile"

    ask "Your name:" USER_NAME

    # Timezone auto-detect
    local detected_tz=""
    if [[ "$(uname)" == "Darwin" ]]; then
        detected_tz=$(readlink /etc/localtime 2>/dev/null | sed 's|.*/zoneinfo/||' || true)
    elif [[ -f /etc/timezone ]]; then
        detected_tz=$(cat /etc/timezone 2>/dev/null || true)
    fi
    detected_tz="${detected_tz:-America/New_York}"

    ask_default "Timezone:" "$detected_tz" TIMEZONE

    # Notes folder — detect cloud storage options
    echo ""
    echo "  Where should your files be stored?"
    echo "  Using a cloud folder enables mobile access (Obsidian) and family sharing."
    echo ""

    local folder_options=()
    local folder_labels=()
    local default_choice=1
    local option_num=1

    # Detect available cloud storage locations
    local icloud_obsidian="$HOME/Library/Mobile Documents/iCloud~md~obsidian/Documents"
    local icloud_docs="$HOME/Library/Mobile Documents/com~apple~CloudDocs/Documents"
    local dropbox="$HOME/Dropbox"
    local gdrive="$HOME/Google Drive"
    local onedrive="$HOME/OneDrive"

    if [[ -d "$icloud_obsidian" ]]; then
        folder_options+=("$icloud_obsidian/Personal Assistant")
        folder_labels+=("iCloud (Obsidian vault) — best for mobile access + family sharing")
        default_choice=$option_num
        option_num=$((option_num + 1))
    fi
    if [[ -d "$icloud_docs" ]]; then
        folder_options+=("$icloud_docs/Personal Assistant")
        folder_labels+=("iCloud Documents — syncs across Apple devices")
        option_num=$((option_num + 1))
    fi
    if [[ -d "$dropbox" ]]; then
        folder_options+=("$dropbox/Personal Assistant")
        folder_labels+=("Dropbox — cross-platform sync")
        option_num=$((option_num + 1))
    fi
    if [[ -d "$gdrive" ]]; then
        folder_options+=("$gdrive/Personal Assistant")
        folder_labels+=("Google Drive — cross-platform sync")
        option_num=$((option_num + 1))
    fi
    if [[ -d "$onedrive" ]]; then
        folder_options+=("$onedrive/Personal Assistant")
        folder_labels+=("OneDrive — cross-platform sync")
        option_num=$((option_num + 1))
    fi

    # Always offer local option
    folder_options+=("$HOME/Documents/Personal Assistant")
    folder_labels+=("Local only — ~/Documents/Personal Assistant")
    option_num=$((option_num + 1))

    # Always offer custom
    folder_options+=("custom")
    folder_labels+=("Custom path")

    for i in "${!folder_labels[@]}"; do
        echo "    $((i+1)). ${folder_labels[$i]}"
    done
    echo ""

    ask_default "Choice:" "$default_choice" folder_choice

    local idx=$((folder_choice - 1))
    if [[ "${folder_options[$idx]}" == "custom" ]]; then
        ask "Enter full path:" NOTES_FOLDER
    else
        NOTES_FOLDER="${folder_options[$idx]}"
    fi

    print_success "Profile: $USER_NAME | $TIMEZONE"
    print_success "Notes folder: $NOTES_FOLDER"
}

# ─── (Steps 7-8 removed — schedule and workstreams are now set up
# ─── conversationally by the AI during first run. See framework/Getting Started.md)

# ─── (Step 9 removed — features are now configured conversationally
# ─── by the AI during onboarding. See framework/Automations.md)

# ─── Step 10: Family Extension ──────────────────────────────────────

ENABLE_FAMILY=false
FAMILY_NAME=""; FAMILY_CHANNEL_ID=""; FAMILY_CHANNEL_NAME=""
FAMILY_NOTES_FOLDER=""

collect_family() {
    print_step "Step 10: Family Extension (Optional)"

    if ! confirm "Set up a second user (spouse/partner)?"; then return; fi

    ENABLE_FAMILY=true
    ask "Their name:" FAMILY_NAME
    ask "Their Slack channel ID:" FAMILY_CHANNEL_ID
    ask_default "Their channel name:" "#${FAMILY_NAME,,}-cowork" FAMILY_CHANNEL_NAME
    ask_default "Their notes folder:" "$(dirname "$NOTES_FOLDER")/Personal Assistant - $FAMILY_NAME" FAMILY_NOTES_FOLDER

    print_success "Family: $FAMILY_NAME at $FAMILY_CHANNEL_NAME"
}

# ─── File Generation ────────────────────────────────────────────────

apply_substitutions() {
    local file="$1"
    do_sed "s|{{USER_NAME}}|${USER_NAME}|g" "$file"
    do_sed "s|{{SLACK_CHANNEL_ID}}|${SLACK_CHANNEL_ID}|g" "$file"
    do_sed "s|{{SLACK_CHANNEL_NAME}}|${SLACK_CHANNEL_NAME}|g" "$file"
    do_sed "s|{{TIMEZONE}}|${TIMEZONE}|g" "$file"
    do_sed "s|{{NOTES_FOLDER}}|${NOTES_FOLDER}|g" "$file"
    if [[ "$ENABLE_FAMILY" == true ]]; then
        do_sed "s|{{FAMILY_NAME}}|${FAMILY_NAME}|g" "$file"
        do_sed "s|{{CROSS_TASKS_PATH}}|$(dirname "$NOTES_FOLDER")/cross-tasks.json|g" "$file"
    fi
}

# (replace_block and apply_conditionals removed — no longer needed
# since framework files have no template placeholders)

generate_files() {
    print_step "Generating Files"

    mkdir -p "$NOTES_FOLDER"

    local framework_src="$SCRIPT_DIR/framework"

    # Copy all framework files to the user's notes folder
    for f in "$framework_src"/*.md; do
        local basename
        basename=$(basename "$f")
        if [[ ! -f "$NOTES_FOLDER/$basename" ]]; then
            cp "$f" "$NOTES_FOLDER/$basename"
            print_success "$basename"
        else
            print_warning "$basename already exists — skipping"
        fi
    done

    # Create reminders.json if not exists
    if [[ ! -f "$NOTES_FOLDER/reminders.json" ]]; then
        echo "[]" > "$NOTES_FOLDER/reminders.json"
        print_success "reminders.json"
    fi

    # Copy the system prompt (for daemon/cowork mode)
    local prompt_tpl="$SCRIPT_DIR/templates/prompts/$LANG_CODE"
    if [[ -d "$prompt_tpl" ]]; then
        mkdir -p "$NOTES_FOLDER/skills/mission-control"
        cp "$prompt_tpl/system-prompt.md.tpl" "$NOTES_FOLDER/skills/mission-control/SKILL.md"
        apply_substitutions "$NOTES_FOLDER/skills/mission-control/SKILL.md"
        print_success "skills/mission-control/SKILL.md"
    fi

    echo ""
    print_success "Framework files copied to: $NOTES_FOLDER"
    echo ""
    echo "  Your schedule and workstreams will be set up conversationally"
    echo "  when the AI connects for the first time."
    echo "  Or: open 'Getting Started.md' in any AI to do it now."
}

# ─── Install Dependencies (Daemon Mode) ─────────────────────────────

install_deps() {
    if [[ "$SETUP_MODE" != "daemon" ]]; then return; fi

    print_step "Step 12: Installing Dependencies"

    if python3 -m pip install -r "$SCRIPT_DIR/daemon/requirements.txt" --quiet 2>/dev/null; then
        print_success "Python dependencies installed"
    else
        print_warning "Could not install automatically. Run manually:"
        echo "    pip install -r $SCRIPT_DIR/daemon/requirements.txt"
    fi

    # Create .env
    local env_file="$NOTES_FOLDER/.env"
    echo "SLACK_BOT_TOKEN=$SLACK_BOT_TOKEN" > "$env_file"
    print_success ".env created (bot token stored)"
}

# ─── Create Scheduled Tasks (Cowork Mode) ───────────────────────────

create_cowork_tasks() {
    if [[ "$SETUP_MODE" != "cowork" ]]; then return; fi

    print_step "Step 12: Creating Scheduled Tasks"

    local tasks_dir="$HOME/.claude/scheduled-tasks"
    local tpl_dir="$SCRIPT_DIR/cowork/scheduled"

    for tpl in "$tpl_dir"/*.tpl; do
        local task_name
        task_name=$(basename "$tpl" .tpl)
        local task_dir="$tasks_dir/$task_name"

        # Skip disabled features
        case "$task_name" in
            mc-morning-dispatch)  if [[ "$ENABLE_DISPATCH" != true ]]; then continue; fi ;;
            mc-midday-checkin)    if [[ "$ENABLE_MIDDAY" != true ]]; then continue; fi ;;
            mc-afternoon-checkin) if [[ "$ENABLE_AFTERNOON" != true ]]; then continue; fi ;;
            mc-eod-summary)       if [[ "$ENABLE_EOD" != true ]]; then continue; fi ;;
            mc-friday-summary)    if [[ "$ENABLE_WEEKLY_REVIEW" != true ]]; then continue; fi ;;
            mc-sunday-planning)   if [[ "$ENABLE_WEEKLY_PLAN" != true ]]; then continue; fi ;;
        esac

        mkdir -p "$task_dir"
        cp "$tpl" "$task_dir/SKILL.md"
        apply_substitutions "$task_dir/SKILL.md"
        print_success "$task_name"
    done
}

# ─── Save Config ────────────────────────────────────────────────────

save_config() {
    cat > "$NOTES_FOLDER/.mc-config.json" <<CONF
{
  "version": "$VERSION",
  "setup_mode": "$SETUP_MODE",
  "user_name": "$USER_NAME",
  "slack_channel_id": "$SLACK_CHANNEL_ID",
  "slack_channel_name": "$SLACK_CHANNEL_NAME",
  "timezone": "$TIMEZONE",
  "notes_folder": "$NOTES_FOLDER",
  "language": "$LANG_CODE",
  "llm_provider": "$LLM_PROVIDER",
  "channel_provider": "${CHANNEL_PROVIDER:-slack}",
  "family": $ENABLE_FAMILY,
  "onboarding_complete": false,
  "setup_date": "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
}
CONF
    print_success "Config saved: .mc-config.json"
}

# ─── Start Daemon ───────────────────────────────────────────────────

setup_daemon_service() {
    if [[ "$SETUP_MODE" != "daemon" ]]; then return; fi

    print_step "Step 13: Start Daemon"

    echo "  How would you like to run the daemon?"
    echo ""
    echo "    1. Background service (auto-starts on boot, recommended)"
    echo "    2. Manual (run it yourself when needed)"
    echo ""

    ask_default "Choice:" "1" daemon_choice

    if [[ "$daemon_choice" == "1" ]]; then
        if [[ "$(uname)" == "Darwin" ]]; then
            setup_launchd
        else
            setup_systemd
        fi
    else
        echo ""
        echo "  To start manually:"
        echo "    cd $SCRIPT_DIR"
        echo "    MC_CONFIG=\"$NOTES_FOLDER/.mc-config.json\" python3 -m daemon.main"
        echo ""
    fi
}

setup_launchd() {
    local plist_dir="$HOME/Library/LaunchAgents"
    local plist_file="$plist_dir/com.mission-control.daemon.plist"

    mkdir -p "$plist_dir"

    cat > "$plist_file" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>com.mission-control.daemon</string>
    <key>ProgramArguments</key>
    <array>
        <string>$(which python3)</string>
        <string>-m</string>
        <string>daemon.main</string>
    </array>
    <key>WorkingDirectory</key>
    <string>$SCRIPT_DIR</string>
    <key>RunAtLoad</key>
    <true/>
    <key>KeepAlive</key>
    <true/>
    <key>EnvironmentVariables</key>
    <dict>
        <key>MC_CONFIG</key>
        <string>$NOTES_FOLDER/.mc-config.json</string>
        <key>SLACK_BOT_TOKEN</key>
        <string>$SLACK_BOT_TOKEN</string>
    </dict>
    <key>StandardOutPath</key>
    <string>$HOME/.mission-control.log</string>
    <key>StandardErrorPath</key>
    <string>$HOME/.mission-control.err</string>
</dict>
</plist>
PLIST

    launchctl load "$plist_file" 2>/dev/null || true
    launchctl start com.mission-control.daemon 2>/dev/null || true

    print_success "launchd service created and started"
    echo "    Logs: $HOME/.mission-control.log"
    echo "    Stop: launchctl stop com.mission-control.daemon"
    echo "    Uninstall: launchctl unload $plist_file && rm $plist_file"
}

setup_systemd() {
    local service_dir="$HOME/.config/systemd/user"
    local service_file="$service_dir/mission-control.service"

    mkdir -p "$service_dir"

    cat > "$service_file" <<SERVICE
[Unit]
Description=Personal Assistant Daemon
After=network.target

[Service]
Type=simple
ExecStart=$(which python3) -m daemon.main
WorkingDirectory=$SCRIPT_DIR
Environment=MC_CONFIG=$NOTES_FOLDER/.mc-config.json
Environment=SLACK_BOT_TOKEN=$SLACK_BOT_TOKEN
Restart=always
RestartSec=10

[Install]
WantedBy=default.target
SERVICE

    systemctl --user daemon-reload 2>/dev/null || true
    systemctl --user enable mission-control 2>/dev/null || true
    systemctl --user start mission-control 2>/dev/null || true

    print_success "systemd service created and started"
    echo "    Status: systemctl --user status mission-control"
    echo "    Logs: journalctl --user -u mission-control -f"
    echo "    Stop: systemctl --user stop mission-control"
}

# ─── Print Summary ──────────────────────────────────────────────────

print_summary() {
    echo ""
    echo -e "  ${BOLD}╔═══════════════════════════════════════════╗${NC}"
    echo -e "  ${BOLD}║         Setup Complete!                    ║${NC}"
    echo -e "  ${BOLD}╚═══════════════════════════════════════════╝${NC}"
    echo ""
    echo "  Mode:          $SETUP_MODE"
    echo "  Notes folder:  $NOTES_FOLDER"
    echo "  LLM provider:  $LLM_PROVIDER"
    echo "  Channel:       $SLACK_CHANNEL_NAME"
    echo ""

    echo "  Next steps:"
    echo "    1. The AI will reach out in Slack to learn about your"
    echo "       schedule and projects (the onboarding conversation)"
    echo "    2. Or: open 'Getting Started.md' in any AI to do it now"
    echo "    3. Open your notes folder in Obsidian for mobile access"

    echo ""
    echo -e "  ${GREEN}Enjoy your AI-powered life management system!${NC}"
    echo ""
}

# ─── Main ───────────────────────────────────────────────────────────

main() {
    parse_args "$@"
    show_banner
    check_system
    collect_mode
    collect_language
    collect_llm
    collect_channel
    collect_profile
    collect_family
    generate_files
    install_deps
    create_cowork_tasks
    save_config
    setup_daemon_service
    print_summary
}

main "$@"
