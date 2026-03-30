#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
VERSION="2.0.0"
SETUP_MODE="daemon"

# ─── Logging ────────────────────────────────────────────────────
# All output goes to both terminal and log file

LOG_DIR="$SCRIPT_DIR/logs"
mkdir -p "$LOG_DIR"
LOG_FILE="$LOG_DIR/setup-$(date +%Y%m%d-%H%M%S).log"
exec > >(tee -a "$LOG_FILE") 2>&1

# ─── Defaults (overridden by existing config if found) ──────────

USER_NAME=""
ASSISTANT_NAME=""
SLACK_BOT_TOKEN=""
SLACK_CHANNEL_ID=""
SLACK_CHANNEL_NAME=""
TIMEZONE=""
NOTES_FOLDER=""
LANG_CODE="en"
LLM_PROVIDER="claude-cli"
CHANNEL_PROVIDER="slack"
ENABLE_FAMILY=false
FAMILY_NAME=""
FAMILY_CHANNEL_ID=""
FAMILY_CHANNEL_NAME=""
FAMILY_NOTES_FOLDER=""
EXISTING_CONFIG=""

# ─── Colors & Helpers ───────────────────────────────────────────

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

confirm_no() {
    local ans
    read -rp "$(echo -e "  ${BOLD}$1${NC} ${DIM}[y/N]${NC} ")" ans
    [[ "$ans" =~ ^[Yy] ]]
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

do_sed() {
    if [[ "$(uname)" == "Darwin" ]]; then
        sed -i '' "$@"
    else
        sed -i "$@"
    fi
}

# Helper: extract a string value from JSON (no jq dependency)
json_val() {
    local key="$1" file="$2"
    python3 -c "import json; print(json.load(open('$file')).get('$key',''))" 2>/dev/null || echo ""
}

# ─── Banner ─────────────────────────────────────────────────────

show_banner() {
    echo ""
    echo -e "${BOLD}╔═══════════════════════════════════════════════════╗${NC}"
    echo -e "${BOLD}║   Smart Personal Assistant                        ║${NC}"
    echo -e "${BOLD}║   v${VERSION}                                            ║${NC}"
    echo -e "${BOLD}╚═══════════════════════════════════════════════════╝${NC}"
    echo ""
}

# ─── Parse CLI Args ─────────────────────────────────────────────

parse_args() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            --mode) SETUP_MODE="$2"; shift 2 ;;
            *) shift ;;
        esac
    done
}

# ─── Detect Existing Setup ──────────────────────────────────────

detect_existing() {
    # Search for existing .mc-config.json
    local home="$HOME"
    local candidates=(
        "$home/Library/Mobile Documents/iCloud~md~obsidian/Documents/Personal Assistant/.mc-config.json"
        "$home/Library/Mobile Documents/com~apple~CloudDocs/Documents/Personal Assistant/.mc-config.json"
        "$home/Documents/Personal Assistant/.mc-config.json"
        "$home/Dropbox/Personal Assistant/.mc-config.json"
        "$home/Google Drive/Personal Assistant/.mc-config.json"
        "$home/OneDrive/Personal Assistant/.mc-config.json"
    )

    local found=()
    for c in "${candidates[@]}"; do
        if [[ -f "$c" ]]; then
            found+=("$c")
        fi
    done

    # Also search ~/Documents subdirs
    if [[ -d "$home/Documents" ]]; then
        for d in "$home/Documents"/*/; do
            if [[ -f "${d}.mc-config.json" ]]; then
                local already=false
                for f in "${found[@]+"${found[@]}"}"; do
                    if [[ "$f" == "${d}.mc-config.json" ]]; then
                        already=true
                        break
                    fi
                done
                if [[ "$already" == false ]]; then
                    found+=("${d}.mc-config.json")
                fi
            fi
        done
    fi

    if [[ ${#found[@]} -eq 0 ]]; then
        return
    fi

    print_step "Existing Setup Found"

    for i in "${!found[@]}"; do
        local cfg="${found[$i]}"
        local name
        name=$(json_val "user_name" "$cfg")
        local folder
        folder=$(dirname "$cfg")
        echo "    $((i+1)). ${name:-Unknown} — $folder"
    done
    echo "    $((${#found[@]}+1)). Start fresh"
    echo ""

    ask_default "Choice:" "1" existing_choice

    local idx=$((existing_choice - 1))
    if [[ $idx -lt ${#found[@]} ]]; then
        EXISTING_CONFIG="${found[$idx]}"
        load_existing_config
    fi
}

load_existing_config() {
    local cfg="$EXISTING_CONFIG"
    echo ""
    print_success "Loading previous setup..."

    USER_NAME=$(json_val "user_name" "$cfg")
    ASSISTANT_NAME=$(json_val "assistant_name" "$cfg")
    SLACK_CHANNEL_ID=$(json_val "slack_channel_id" "$cfg")
    SLACK_CHANNEL_NAME=$(json_val "slack_channel_name" "$cfg")
    TIMEZONE=$(json_val "timezone" "$cfg")
    NOTES_FOLDER=$(json_val "notes_folder" "$cfg")
    LANG_CODE=$(json_val "language" "$cfg")
    LLM_PROVIDER=$(json_val "llm_provider" "$cfg")
    CHANNEL_PROVIDER=$(json_val "channel_provider" "$cfg")
    SETUP_MODE=$(json_val "setup_mode" "$cfg")

    # Load bot token from .env if it exists
    local env_file="$NOTES_FOLDER/.env"
    if [[ -f "$env_file" ]]; then
        SLACK_BOT_TOKEN=$(grep '^SLACK_BOT_TOKEN=' "$env_file" 2>/dev/null | cut -d= -f2- || echo "")
    fi

    # Load family settings
    local family_val
    family_val=$(python3 -c "import json; print(json.load(open('$cfg')).get('family', False))" 2>/dev/null || echo "False")
    if [[ "$family_val" == "True" ]]; then
        ENABLE_FAMILY=true
        FAMILY_NAME=$(json_val "family_name" "$cfg")
        FAMILY_CHANNEL_ID=$(json_val "family_channel_id" "$cfg")
        FAMILY_NOTES_FOLDER=$(json_val "family_notes_folder" "$cfg")
        FAMILY_CHANNEL_NAME="#${FAMILY_NAME,,}-cowork"
    fi

    echo "    Name:      $USER_NAME"
    echo "    Assistant: $ASSISTANT_NAME"
    echo "    Channel:   $SLACK_CHANNEL_NAME ($SLACK_CHANNEL_ID)"
    echo "    Folder:  $NOTES_FOLDER"
    echo "    Lang:    $LANG_CODE"
    echo ""
}

# ─── Step 1: System Check ──────────────────────────────────────

check_system() {
    print_step "System Check"

    if command -v python3 &>/dev/null; then
        local pyver
        pyver=$(python3 --version 2>&1 | awk '{print $2}')
        print_success "Python $pyver"
    else
        print_error "Python 3 not found"
        echo "    Install Python 3.10+: https://www.python.org/downloads/"
        exit 1
    fi

    if python3 -m pip --version &>/dev/null 2>&1; then
        print_success "pip available"
    else
        print_warning "pip not found — you'll need it to install dependencies"
    fi

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

# ─── Setup Mode ─────────────────────────────────────────────────

collect_mode() {
    if [[ "$SETUP_MODE" != "daemon" && "$SETUP_MODE" != "cowork" ]]; then
        print_step "Setup Mode"

        echo "    1. ${BOLD}Daemon mode${NC} (recommended) — ~15-20K tokens/day"
        echo "    2. ${BOLD}Cowork mode${NC} — ~60-80K tokens/day"
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

# ─── Language ───────────────────────────────────────────────────

collect_language() {
    print_step "Language / 语言"

    local default_lang="1"
    if [[ "$LANG_CODE" == "zh" ]]; then
        default_lang="2"
    fi

    echo "    1. English"
    echo "    2. 中文"

    ask_default "Choice:" "$default_lang" lang_choice

    if [[ "$lang_choice" == "2" ]]; then
        LANG_CODE="zh"
        print_success "语言：中文"
    else
        LANG_CODE="en"
        print_success "Language: English"
    fi
}

# ─── LLM Provider ──────────────────────────────────────────────

collect_llm() {
    if [[ "$SETUP_MODE" == "cowork" ]]; then
        LLM_PROVIDER="claude-desktop"
        return
    fi

    print_step "LLM Provider"

    echo "    1. Claude (Anthropic) — uses Pro/Max subscription via CLI (recommended)"
    echo "    2. Ollama — free, runs locally (coming soon)"
    echo "    3. Custom — any OpenAI-compatible API (coming soon)"

    ask_default "Choice:" "1" llm_choice
    LLM_PROVIDER="claude-cli"

    if command -v claude &>/dev/null; then
        print_success "Claude CLI is available"
    fi
}

# ─── Chat Channel ──────────────────────────────────────────────

collect_channel() {
    print_step "Chat Channel"

    # If we have existing Slack config, offer to keep it
    if [[ -n "$SLACK_CHANNEL_ID" && -n "$SLACK_BOT_TOKEN" ]]; then
        echo "  Current Slack configuration:"
        echo "    Channel: $SLACK_CHANNEL_NAME ($SLACK_CHANNEL_ID)"
        echo "    Bot Token: ${SLACK_BOT_TOKEN:0:10}...${SLACK_BOT_TOKEN: -4}"
        echo ""

        if ! confirm_no "Change Slack configuration?"; then
            print_success "Keeping existing Slack configuration"
            CHANNEL_PROVIDER="slack"
            return
        fi
        echo ""
    fi

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

    local app_name="$ASSISTANT_NAME"

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

    local encoded_manifest
    encoded_manifest=$(python3 -c "import urllib.parse, sys; print(urllib.parse.quote(sys.stdin.read()))" <<< "$manifest")

    echo -e "  ${BOLD}Step 1/3: Create the Slack App${NC}"
    echo "    → Opening Slack with all permissions pre-filled..."
    echo "    → Just select your workspace and click 'Create'"
    open_url "https://api.slack.com/apps?new_app=1&manifest_json=${encoded_manifest}"
    echo ""
    confirm "Done?" || true

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

    echo ""
    echo -e "  ${BOLD}Step 3/3: Set Up Channel${NC}"
    echo "    → Create a channel (e.g., #my-cowork) or use an existing one"
    echo "    → Invite the bot: /invite @${app_name}"
    echo "    → Get Channel ID: right-click channel → View details → bottom"
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
    ask "Slack Channel ID (starts with C):" SLACK_CHANNEL_ID
    ask_default "Slack channel name:" "#my-cowork" SLACK_CHANNEL_NAME
    CHANNEL_PROVIDER="slack"
}

# ─── User Profile ──────────────────────────────────────────────

collect_identity() {
    print_step "Who Are You?"

    local default_name="${USER_NAME:-}"
    if [[ -n "$default_name" ]]; then
        ask_default "How should I call you?" "$default_name" USER_NAME
    else
        ask "How should I call you?" USER_NAME
    fi

    # Assistant name
    local default_assistant="${ASSISTANT_NAME:-Personal Assistant}"
    if [[ "$LANG_CODE" == "zh" ]]; then
        default_assistant="${ASSISTANT_NAME:-智能管家}"
    fi
    ask_default "Name your assistant:" "$default_assistant" ASSISTANT_NAME

    print_success "$ASSISTANT_NAME for $USER_NAME"
}

collect_profile() {
    print_step "Storage & Timezone"

    # Timezone
    local detected_tz=""
    if [[ "$(uname)" == "Darwin" ]]; then
        detected_tz=$(readlink /etc/localtime 2>/dev/null | sed 's|.*/zoneinfo/||' || true)
    elif [[ -f /etc/timezone ]]; then
        detected_tz=$(cat /etc/timezone 2>/dev/null || true)
    fi
    local default_tz="${TIMEZONE:-${detected_tz:-America/New_York}}"

    ask_default "Timezone:" "$default_tz" TIMEZONE

    # Notes folder
    if [[ -n "$NOTES_FOLDER" ]]; then
        # Already have a folder from existing config
        ask_default "Notes folder:" "$NOTES_FOLDER" NOTES_FOLDER
    else
        # Detect cloud storage options
        echo ""
        echo "  Where should your files be stored?"
        echo "  Using a cloud folder enables mobile access (Obsidian) and family sharing."
        echo ""

        local folder_options=()
        local folder_labels=()
        local default_choice=1
        local option_num=1

        local icloud_obsidian="$HOME/Library/Mobile Documents/iCloud~md~obsidian/Documents"
        local icloud_docs="$HOME/Library/Mobile Documents/com~apple~CloudDocs/Documents"
        local dropbox="$HOME/Dropbox"
        local gdrive="$HOME/Google Drive"
        local onedrive="$HOME/OneDrive"

        if [[ -d "$icloud_obsidian" ]]; then
            folder_options+=("$icloud_obsidian/Personal Assistant")
            folder_labels+=("iCloud (Obsidian vault) — best for mobile + family sharing")
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

        folder_options+=("$HOME/Documents/Personal Assistant")
        folder_labels+=("Local only — ~/Documents/Personal Assistant")
        option_num=$((option_num + 1))

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
    fi

    print_success "Timezone: $TIMEZONE"
    print_success "Notes folder: $NOTES_FOLDER"
}

# ─── Family Extension ──────────────────────────────────────────

collect_family() {
    print_step "Family Extension (Optional)"

    if [[ "$ENABLE_FAMILY" == true ]]; then
        echo "  Current family setup: $FAMILY_NAME ($FAMILY_CHANNEL_ID)"
        echo ""
        if ! confirm_no "Change family configuration?"; then
            print_success "Keeping existing family setup"
            return
        fi
    fi

    if ! confirm "Set up a second user (spouse/partner)?"; then
        ENABLE_FAMILY=false
        return
    fi

    ENABLE_FAMILY=true
    local default_fname="${FAMILY_NAME:-}"
    if [[ -n "$default_fname" ]]; then
        ask_default "Their name:" "$default_fname" FAMILY_NAME
    else
        ask "Their name:" FAMILY_NAME
    fi
    ask_default "Their Slack channel ID:" "${FAMILY_CHANNEL_ID:-}" FAMILY_CHANNEL_ID
    ask_default "Their channel name:" "${FAMILY_CHANNEL_NAME:-#${FAMILY_NAME,,}-cowork}" FAMILY_CHANNEL_NAME
    ask_default "Their notes folder:" "${FAMILY_NOTES_FOLDER:-$(dirname "$NOTES_FOLDER")/Personal Assistant - $FAMILY_NAME}" FAMILY_NOTES_FOLDER

    print_success "Family: $FAMILY_NAME at $FAMILY_CHANNEL_NAME"
}

# ─── File Generation ───────────────────────────────────────────

apply_substitutions() {
    local file="$1"
    do_sed "s|{{USER_NAME}}|${USER_NAME}|g" "$file"
    do_sed "s|{{ASSISTANT_NAME}}|${ASSISTANT_NAME}|g" "$file"
    do_sed "s|{{SLACK_CHANNEL_ID}}|${SLACK_CHANNEL_ID}|g" "$file"
    do_sed "s|{{SLACK_CHANNEL_NAME}}|${SLACK_CHANNEL_NAME}|g" "$file"
    do_sed "s|{{TIMEZONE}}|${TIMEZONE}|g" "$file"
    do_sed "s|{{NOTES_FOLDER}}|${NOTES_FOLDER}|g" "$file"
    if [[ "$ENABLE_FAMILY" == true ]]; then
        do_sed "s|{{FAMILY_NAME}}|${FAMILY_NAME}|g" "$file"
        do_sed "s|{{CROSS_TASKS_PATH}}|$(dirname "$NOTES_FOLDER")/cross-tasks.json|g" "$file"
    fi
}

generate_files() {
    print_step "Generating Files"

    mkdir -p "$NOTES_FOLDER"

    local framework_src="$SCRIPT_DIR/framework"

    # Copy framework files (skip existing to preserve user data)
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

    # System prompt (always regenerated with current settings)
    local prompt_tpl="$SCRIPT_DIR/templates/prompts/$LANG_CODE"
    if [[ -d "$prompt_tpl" ]]; then
        mkdir -p "$NOTES_FOLDER/skills/mission-control"
        cp "$prompt_tpl/system-prompt.md.tpl" "$NOTES_FOLDER/skills/mission-control/SKILL.md"
        apply_substitutions "$NOTES_FOLDER/skills/mission-control/SKILL.md"
        print_success "skills/mission-control/SKILL.md (updated)"
    fi

    echo ""
    print_success "Framework files in: $NOTES_FOLDER"
}

# ─── Install Dependencies ──────────────────────────────────────

install_deps() {
    if [[ "$SETUP_MODE" != "daemon" ]]; then return; fi

    print_step "Installing Dependencies"

    local venv_dir="$SCRIPT_DIR/.venv"

    # Create venv if it doesn't exist
    if [[ ! -d "$venv_dir" ]]; then
        echo "  Creating virtual environment..."
        python3 -m venv "$venv_dir"
    fi
    print_success "Virtual environment: .venv/"

    # Install deps in venv
    if "$venv_dir/bin/pip" install -r "$SCRIPT_DIR/daemon/requirements.txt" --quiet 2>/dev/null; then
        print_success "Python dependencies installed"
    else
        print_warning "Could not install automatically. Run manually:"
        echo "    $venv_dir/bin/pip install -r $SCRIPT_DIR/daemon/requirements.txt"
    fi

    # Create/update .env
    local env_file="$NOTES_FOLDER/.env"
    echo "SLACK_BOT_TOKEN=$SLACK_BOT_TOKEN" > "$env_file"
    print_success ".env updated (bot token stored)"
}

# ─── Create Scheduled Tasks (Cowork Mode) ──────────────────────

create_cowork_tasks() {
    if [[ "$SETUP_MODE" != "cowork" ]]; then return; fi

    print_step "Creating Scheduled Tasks"

    local tasks_dir="$HOME/.claude/scheduled-tasks"
    local tpl_dir="$SCRIPT_DIR/cowork/scheduled"

    for tpl in "$tpl_dir"/*.tpl; do
        local task_name
        task_name=$(basename "$tpl" .tpl)
        local task_dir="$tasks_dir/$task_name"

        mkdir -p "$task_dir"
        cp "$tpl" "$task_dir/SKILL.md"
        apply_substitutions "$task_dir/SKILL.md"
        print_success "$task_name"
    done
}

# ─── Save Config ───────────────────────────────────────────────

save_config() {
    cat > "$NOTES_FOLDER/.mc-config.json" <<CONF
{
  "version": "$VERSION",
  "setup_mode": "$SETUP_MODE",
  "user_name": "$USER_NAME",
  "assistant_name": "$ASSISTANT_NAME",
  "slack_channel_id": "$SLACK_CHANNEL_ID",
  "slack_channel_name": "$SLACK_CHANNEL_NAME",
  "timezone": "$TIMEZONE",
  "notes_folder": "$NOTES_FOLDER",
  "language": "$LANG_CODE",
  "llm_provider": "$LLM_PROVIDER",
  "channel_provider": "${CHANNEL_PROVIDER:-slack}",
  "family": $ENABLE_FAMILY,
  "family_name": "$FAMILY_NAME",
  "family_channel_id": "$FAMILY_CHANNEL_ID",
  "family_notes_folder": "$FAMILY_NOTES_FOLDER",
  "setup_date": "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
}
CONF
    print_success "Config saved: .mc-config.json"
}

# ─── Start Daemon ──────────────────────────────────────────────

setup_daemon_service() {
    if [[ "$SETUP_MODE" != "daemon" ]]; then return; fi
    if [[ "$SKIP_DAEMON_SETUP" == true ]]; then return; fi

    print_step "Start Daemon"

    echo "    1. Background service (auto-starts on boot)"
    echo "    2. Manual (run ./run.sh yourself)"
    echo ""

    ask_default "Choice:" "1" daemon_choice

    if [[ "$daemon_choice" == "1" ]]; then
        if [[ "$(uname)" == "Darwin" ]]; then
            setup_launchd
        else
            setup_systemd
        fi

        # Verify the daemon is running
        echo ""
        echo "  Verifying daemon is running..."
        sleep 2

        if [[ "$(uname)" == "Darwin" ]]; then
            if launchctl list 2>/dev/null | grep -q "com.mission-control.daemon"; then
                print_success "Daemon is running"
            else
                print_warning "Daemon may not have started. Check logs:"
                echo "    cat $HOME/.mission-control.log"
                echo "    cat $HOME/.mission-control.err"
            fi
        else
            if systemctl --user is-active mission-control &>/dev/null; then
                print_success "Daemon is running"
            else
                print_warning "Daemon may not have started. Check:"
                echo "    systemctl --user status mission-control"
            fi
        fi

        # Test Slack connection
        echo ""
        if confirm "Send a test message to $SLACK_CHANNEL_NAME to verify Slack is working?"; then
            echo "  Sending test message..."
            local test_result
            test_result=$("$SCRIPT_DIR/.venv/bin/python3" -c "
from slack_sdk import WebClient
client = WebClient(token='$SLACK_BOT_TOKEN')
try:
    client.chat_postMessage(channel='$SLACK_CHANNEL_ID', text='Personal Assistant is set up and running! The onboarding conversation will start shortly.')
    print('ok')
except Exception as e:
    print(f'error: {e}')
" 2>&1)
            if [[ "$test_result" == "ok" ]]; then
                print_success "Test message sent! Check $SLACK_CHANNEL_NAME"
            else
                print_error "Could not send message: $test_result"
                echo "    Check that:"
                echo "      - Bot token is correct"
                echo "      - Bot is invited to the channel"
                echo "      - Channel ID is correct"
            fi
        fi
    else
        echo ""
        echo "  To start manually:"
        echo "    cd $SCRIPT_DIR"
        echo "    ./run.sh"
        echo ""
        echo "  To verify it's working:"
        echo "    ./run.sh --once    (runs one cycle and exits)"
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
        <string>$SCRIPT_DIR/.venv/bin/python3</string>
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

    launchctl unload "$plist_file" 2>/dev/null || true
    launchctl load "$plist_file" 2>/dev/null || true

    print_success "launchd service created and started"
    echo "    Logs: $HOME/.mission-control.log"
    echo "    Stop: launchctl stop com.mission-control.daemon"
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
ExecStart=$SCRIPT_DIR/.venv/bin/python3 -m daemon.main
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
    systemctl --user restart mission-control 2>/dev/null || true

    print_success "systemd service created and started"
    echo "    Status: systemctl --user status mission-control"
    echo "    Logs: journalctl --user -u mission-control -f"
}

# ─── Restart Running Daemon ──────────────────────────────────────

restart_if_running() {
    if [[ "$SETUP_MODE" != "daemon" ]]; then return; fi

    local was_running=false

    if [[ "$(uname)" == "Darwin" ]]; then
        if launchctl list 2>/dev/null | grep -q "com.mission-control.daemon"; then
            was_running=true
            print_step "Restarting Daemon"
            echo "  Detected running daemon — restarting with new configuration..."
            launchctl stop com.mission-control.daemon 2>/dev/null || true
            sleep 1
            launchctl start com.mission-control.daemon 2>/dev/null || true
            print_success "Daemon restarted with new configuration"
        fi
    else
        if systemctl --user is-active mission-control &>/dev/null; then
            was_running=true
            print_step "Restarting Daemon"
            echo "  Detected running daemon — restarting with new configuration..."
            systemctl --user restart mission-control 2>/dev/null || true
            print_success "Daemon restarted with new configuration"
        fi
    fi

    if [[ "$was_running" == true ]]; then
        SKIP_DAEMON_SETUP=true
    fi
}

SKIP_DAEMON_SETUP=false

# ─── Summary ───────────────────────────────────────────────────

print_summary() {
    echo ""
    echo -e "  ${BOLD}╔═══════════════════════════════════════════╗${NC}"
    echo -e "  ${BOLD}║         Setup Complete!                    ║${NC}"
    echo -e "  ${BOLD}╚═══════════════════════════════════════════╝${NC}"
    echo ""
    echo "  Mode:      $SETUP_MODE"
    echo "  Assistant: $ASSISTANT_NAME"
    echo "  Folder:    $NOTES_FOLDER"
    echo "  Channel:   $SLACK_CHANNEL_NAME"
    echo ""
    if [[ "$SETUP_MODE" == "daemon" ]]; then
        echo "  What happens next:"
        echo "    1. The daemon checks Slack every minute"
        echo "    2. On first run, the AI will message you in $SLACK_CHANNEL_NAME"
        echo "       to learn about your schedule and projects (~15 min chat)"
        echo "    3. After onboarding, it runs on autopilot — dispatches,"
        echo "       check-ins, reminders, all automatic"
        echo ""
        echo "  Useful commands:"
        echo "    View logs:  tail -f ~/.mission-control.log"
        echo "    Test run:   cd $SCRIPT_DIR && ./run.sh --once"
        echo "    Stop:       launchctl stop com.mission-control.daemon  (macOS)"
        echo "    Re-setup:   ./setup.sh  (preserves your data)"
    else
        echo "  What happens next:"
        echo "    1. Open Claude Desktop → Schedule tab → configure timing"
        echo "    2. The AI will onboard you on first run"
        echo "    3. Open your notes folder in Obsidian for mobile access"
    fi
    echo ""
    echo ""
    echo -e "  ${DIM}Setup log saved to: $LOG_FILE${NC}"
    echo -e "  ${DIM}If you run into issues, attach this log to your GitHub issue.${NC}"
    echo ""
    echo -e "  ${GREEN}Enjoy your AI-powered life management system!${NC}"
    echo ""
}

# ─── Main ──────────────────────────────────────────────────────

main() {
    parse_args "$@"
    show_banner
    detect_existing
    check_system
    collect_mode
    collect_language
    collect_identity
    collect_llm
    collect_channel
    collect_profile
    collect_family
    generate_files
    install_deps
    create_cowork_tasks
    save_config
    restart_if_running
    setup_daemon_service
    print_summary
}

main "$@"
