#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
VERSION="2.0.0"
SETUP_MODE="daemon"

# ─── Logging ────────────────────────────────────────────────────

LOG_DIR="$SCRIPT_DIR/logs"
mkdir -p "$LOG_DIR"
LOG_FILE="$LOG_DIR/setup-$(date +%Y%m%d-%H%M%S).log"
exec > >(tee -a "$LOG_FILE") 2>&1

# ─── Language (loaded early, before any user-facing text) ───────

LANG_CODE="en"

load_language() {
    local lang_file="$SCRIPT_DIR/i18n/${LANG_CODE}.sh"
    if [[ -f "$lang_file" ]]; then
        source "$lang_file"
    else
        source "$SCRIPT_DIR/i18n/en.sh"
    fi
}

# Default to English until user picks
load_language

# ─── Defaults (overridden by existing config if found) ──────────

USER_NAME=""
ASSISTANT_NAME=""
SLACK_BOT_TOKEN=""
SLACK_APP_TOKEN=""
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
    echo -e "${BOLD}║   ${MSG_BANNER_TITLE}${NC}"
    echo -e "${BOLD}║   v${VERSION}${NC}"
    echo -e "${BOLD}║   ${MSG_BANNER_SUBTITLE}${NC}"
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

    print_step "$MSG_EXISTING_FOUND"

    for i in "${!found[@]}"; do
        local cfg="${found[$i]}"
        local name
        name=$(json_val "user_name" "$cfg")
        local folder
        folder=$(dirname "$cfg")
        echo "    $((i+1)). ${name:-Unknown} — $folder"
    done
    echo "    $((${#found[@]}+1)). $MSG_EXISTING_START_FRESH"
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
    print_success "$MSG_EXISTING_LOADING"

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

    # Load tokens from .env if it exists
    local env_file="$NOTES_FOLDER/.env"
    if [[ -f "$env_file" ]]; then
        SLACK_BOT_TOKEN=$(grep '^SLACK_BOT_TOKEN=' "$env_file" 2>/dev/null | cut -d= -f2- || echo "")
        SLACK_APP_TOKEN=$(grep '^SLACK_APP_TOKEN=' "$env_file" 2>/dev/null | cut -d= -f2- || echo "")
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
    print_step "$MSG_SYSTEM_CHECK"

    if command -v python3 &>/dev/null; then
        local pyver
        pyver=$(python3 --version 2>&1 | awk '{print $2}')
        print_success "Python $pyver"
    else
        print_error "$MSG_PYTHON_NOT_FOUND"
        echo "    Install Python 3.10+: https://www.python.org/downloads/"
        exit 1
    fi

    if python3 -m pip --version &>/dev/null 2>&1; then
        print_success "$MSG_PIP_AVAILABLE"
    else
        print_warning "$MSG_PIP_NOT_FOUND"
    fi

    if [[ "$SETUP_MODE" == "daemon" ]]; then
        if command -v claude &>/dev/null; then
            local clver
            clver=$(claude --version 2>/dev/null || echo "unknown")
            print_success "Claude CLI ($clver)"
        else
            print_warning "$MSG_CLAUDE_NOT_FOUND"
            open_url "https://docs.anthropic.com/en/docs/claude-code"
            if ! confirm "$MSG_CONTINUE_WITHOUT"; then
                exit 1
            fi
        fi
    fi
}

# ─── Setup Mode ─────────────────────────────────────────────────

collect_mode() {
    if [[ "$SETUP_MODE" != "daemon" && "$SETUP_MODE" != "cowork" ]]; then
        print_step "$MSG_MODE_TITLE"

        echo "    1. $MSG_MODE_DAEMON"
        echo "    2. $MSG_MODE_COWORK"
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
    echo ""
    echo "  Language / 语言:"
    echo ""
    echo "    1. English"
    echo "    2. 中文"
    echo ""

    local default_lang="1"
    if [[ "$LANG_CODE" == "zh" ]]; then
        default_lang="2"
    fi

    ask_default "Choice / 选择:" "$default_lang" lang_choice

    if [[ "$lang_choice" == "2" ]]; then
        LANG_CODE="zh"
        load_language
        print_success "语言：中文"
    else
        LANG_CODE="en"
        load_language
        print_success "Language: English"
    fi
}

# ─── LLM Provider ──────────────────────────────────────────────

collect_llm() {
    if [[ "$SETUP_MODE" == "cowork" ]]; then
        LLM_PROVIDER="claude-desktop"
        return
    fi

    print_step "$MSG_LLM_TITLE"

    echo "    1. $MSG_LLM_CLAUDE"
    echo "    2. $MSG_LLM_OLLAMA"
    echo "    3. $MSG_LLM_CUSTOM"

    ask_default "Choice:" "1" llm_choice
    LLM_PROVIDER="claude-cli"

    if command -v claude &>/dev/null; then
        print_success "Claude CLI is available"
    fi
}

# ─── Chat Channel ──────────────────────────────────────────────

collect_channel() {
    print_step "$MSG_CHANNEL_TITLE"

    # If we have existing Slack config, offer to keep it
    if [[ -n "$SLACK_CHANNEL_ID" && -n "$SLACK_BOT_TOKEN" ]]; then
        echo "  Current Slack configuration:"
        echo "    Channel: $SLACK_CHANNEL_NAME ($SLACK_CHANNEL_ID)"
        echo "    Bot Token: ${SLACK_BOT_TOKEN:0:10}...${SLACK_BOT_TOKEN: -4}"
        echo ""

        if ! confirm_no "$MSG_CHANNEL_CHANGE"; then
            print_success "$MSG_CHANNEL_KEEPING"
            CHANNEL_PROVIDER="slack"
            return
        fi
        echo ""
    fi

    echo "    1. $MSG_CHANNEL_SLACK"
    echo "    2. $MSG_CHANNEL_DISCORD"
    echo "    3. $MSG_CHANNEL_TELEGRAM"

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

    # Slack bot display_name must be ASCII-convertible (no Chinese, emoji, etc.)
    # Use the app_name if it's ASCII, otherwise fall back to "assistant"
    local bot_username
    bot_username=$(python3 -c "
name = '''${app_name}'''
ascii_name = name.encode('ascii', 'ignore').decode().strip()
# Remove non-alphanumeric except hyphens/underscores, lowercase
import re
slug = re.sub(r'[^a-zA-Z0-9_-]', '-', ascii_name).strip('-').lower()
print(slug if slug else 'personal-assistant')
" 2>/dev/null || echo "personal-assistant")

    # Generate manifest file
    local manifest_file="$SCRIPT_DIR/logs/slack-manifest.json"
    mkdir -p "$SCRIPT_DIR/logs"
    cat > "$manifest_file" <<MANIFEST
{
  "display_information": {
    "name": "${app_name}",
    "description": "AI-powered personal life management assistant",
    "background_color": "#2c2d30"
  },
  "features": {
    "bot_user": {
      "display_name": "${bot_username}",
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
    "event_subscriptions": {
      "bot_events": [
        "message.channels",
        "message.groups",
        "message.im"
      ]
    },
    "org_deploy_enabled": false,
    "socket_mode_enabled": true,
    "token_rotation_enabled": false
  }
}
MANIFEST

    # URL-encode the manifest
    local encoded_manifest
    encoded_manifest=$(python3 -c "import urllib.parse, json; print(urllib.parse.quote(json.dumps(json.load(open('$manifest_file')))))" 2>/dev/null || echo "")

    # Step 1: Create App
    echo -e "  ${BOLD}Step 1/4: Create the Slack App${NC}"

    if [[ -n "$encoded_manifest" ]]; then
        echo "    1. $MSG_SLACK_OPEN_AUTO"
        open_url "https://api.slack.com/apps?new_app=1&manifest_json=${encoded_manifest}"
        echo "    2. $MSG_SLACK_SELECT_AUTO"
        echo ""
        echo -e "    ${DIM}If Slack shows an error, choose 'From an app manifest' instead,${NC}"
        echo -e "    ${DIM}switch to JSON tab, and paste the contents of:${NC}"
        echo -e "    ${DIM}$manifest_file${NC}"
    else
        echo "    1. $MSG_SLACK_OPEN_MANUAL"
        open_url "https://api.slack.com/apps?new_app=1"
        echo "    2. Choose 'From an app manifest' → select workspace → Next"
        echo "    3. $MSG_SLACK_MANUAL_JSON"
        echo -e "       ${DIM}$manifest_file${NC}"
        echo "    4. $MSG_SLACK_MANUAL_CREATE"
    fi
    echo ""
    confirm "$MSG_DONE" || true

    # Step 2: Install + Copy Bot Token
    echo ""
    echo -e "  ${BOLD}Step 2/4: Install & Copy Bot Token${NC}"
    echo "    → $MSG_SLACK_INSTALL"
    echo "    → $MSG_SLACK_INSTALL2"
    echo "    → $MSG_SLACK_INSTALL3"
    echo ""
    ask "$MSG_SLACK_PASTE" SLACK_BOT_TOKEN

    if [[ ! "$SLACK_BOT_TOKEN" =~ ^xoxb- ]]; then
        print_warning "Token doesn't start with 'xoxb-' — make sure you copied the Bot token, not the User token"
    fi

    # Step 3: App-Level Token (for Socket Mode)
    echo ""
    echo -e "  ${BOLD}Step 3/4: App-Level Token (for instant messages)${NC}"
    echo "    → In your Slack app settings, go to 'Basic Information'"
    echo "    → Scroll down to 'App-Level Tokens'"
    echo "    → Click 'Generate Token and Scopes'"
    echo "    → Name it 'socket-mode', add scope 'connections:write'"
    echo "    → Click 'Generate' and copy the token (starts with xapp-)"
    echo ""
    ask "App-Level Token (xapp-...):" SLACK_APP_TOKEN

    if [[ -n "$SLACK_APP_TOKEN" && ! "$SLACK_APP_TOKEN" =~ ^xapp- ]]; then
        print_warning "Token doesn't start with 'xapp-' — make sure you copied the App-Level Token"
    fi
    if [[ -z "$SLACK_APP_TOKEN" ]]; then
        print_warning "No App-Level Token provided. The daemon will use polling mode (slower)."
    fi

    # Step 4: Channel
    echo ""
    echo -e "  ${BOLD}Step 4/4: Set Up Channel${NC}"
    echo "    → $MSG_SLACK_CHANNEL_CREATE"
    echo -e "    → Invite the bot: /invite @${app_name}"
    echo "    → $MSG_SLACK_CHANNEL_ID_HINT"
    echo ""
    ask "$MSG_SLACK_CHANNEL_ID" SLACK_CHANNEL_ID
    ask_default "$MSG_SLACK_CHANNEL_NAME" "#my-cowork" SLACK_CHANNEL_NAME

    echo ""
    print_success "$MSG_SLACK_DONE"

    # Test connection
    test_slack_connection
}

test_slack_connection() {
    echo ""
    if confirm "$MSG_SLACK_TEST"; then
        while true; do
            echo "  $MSG_SLACK_TEST_SENDING"
            local test_result
            test_result=$("$SCRIPT_DIR/.venv/bin/python3" -c "
from slack_sdk import WebClient
client = WebClient(token='$SLACK_BOT_TOKEN')
try:
    client.chat_postMessage(channel='$SLACK_CHANNEL_ID', text='$MSG_SLACK_TEST_MSG')
    print('ok')
except Exception as e:
    print(f'error: {e}')
" 2>&1 || echo "error: python/venv not ready")

            if [[ "$test_result" == "ok" ]]; then
                print_success "$MSG_SLACK_TEST_OK"
                break
            else
                print_error "$MSG_SLACK_TEST_FAIL"
                echo "    $test_result"
                echo ""
                echo -e "  ${BOLD}$MSG_SLACK_TEST_DEBUG${NC}"
                echo "    $MSG_SLACK_TEST_DEBUG1"
                echo "    $MSG_SLACK_TEST_DEBUG2"
                echo "    $MSG_SLACK_TEST_DEBUG3"
                echo "    $MSG_SLACK_TEST_DEBUG4"
                echo "    $MSG_SLACK_TEST_DEBUG5"
                echo ""
                if ! confirm "$MSG_SLACK_TEST_RETRY"; then
                    break
                fi

                # Re-collect credentials
                echo ""
                echo -e "  ${BOLD}$MSG_SLACK_PASTE${NC}"
                echo -e "  ${DIM}(${SLACK_BOT_TOKEN:0:10}...${SLACK_BOT_TOKEN: -4})${NC}"
                ask_default "$MSG_SLACK_PASTE" "$SLACK_BOT_TOKEN" SLACK_BOT_TOKEN

                echo ""
                echo -e "  ${DIM}($SLACK_CHANNEL_ID)${NC}"
                ask_default "$MSG_SLACK_CHANNEL_ID" "$SLACK_CHANNEL_ID" SLACK_CHANNEL_ID

                echo ""
                echo -e "  ${DIM}($SLACK_CHANNEL_NAME)${NC}"
                ask_default "$MSG_SLACK_CHANNEL_NAME" "$SLACK_CHANNEL_NAME" SLACK_CHANNEL_NAME
            fi
        done
    fi
}

setup_slack_cowork() {
    echo ""
    echo "  $MSG_SLACK_COWORK"
    echo "  $MSG_SLACK_COWORK2"
    echo ""
    ask "$MSG_SLACK_CHANNEL_ID" SLACK_CHANNEL_ID
    ask_default "$MSG_SLACK_CHANNEL_NAME" "#my-cowork" SLACK_CHANNEL_NAME
    CHANNEL_PROVIDER="slack"
}

# ─── User Profile ──────────────────────────────────────────────

collect_identity() {
    print_step "$MSG_IDENTITY_TITLE"

    local default_name="${USER_NAME:-}"
    if [[ -n "$default_name" ]]; then
        ask_default "$MSG_IDENTITY_NAME" "$default_name" USER_NAME
    else
        ask "$MSG_IDENTITY_NAME" USER_NAME
    fi

    # Assistant name
    local default_assistant="${ASSISTANT_NAME:-Personal Assistant}"
    if [[ "$LANG_CODE" == "zh" ]]; then
        default_assistant="${ASSISTANT_NAME:-智能管家}"
    fi
    ask_default "$MSG_IDENTITY_ASSISTANT" "$default_assistant" ASSISTANT_NAME

    print_success "$ASSISTANT_NAME for $USER_NAME"
}

collect_profile() {
    print_step "$MSG_PROFILE_TITLE"

    # Timezone
    local detected_tz=""
    if [[ "$(uname)" == "Darwin" ]]; then
        detected_tz=$(readlink /etc/localtime 2>/dev/null | sed 's|.*/zoneinfo/||' || true)
    elif [[ -f /etc/timezone ]]; then
        detected_tz=$(cat /etc/timezone 2>/dev/null || true)
    fi
    local default_tz="${TIMEZONE:-${detected_tz:-America/New_York}}"

    ask_default "$MSG_PROFILE_TIMEZONE" "$default_tz" TIMEZONE

    # Notes folder
    if [[ -n "$NOTES_FOLDER" ]]; then
        # Already have a folder from existing config
        ask_default "Notes folder:" "$NOTES_FOLDER" NOTES_FOLDER
    else
        # Detect cloud storage options
        echo ""
        echo "  $MSG_PROFILE_FOLDER"
        echo "  $MSG_PROFILE_FOLDER_HINT"
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
            folder_labels+=("$MSG_PROFILE_ICLOUD")
            default_choice=$option_num
            option_num=$((option_num + 1))
        fi
        if [[ -d "$icloud_docs" ]]; then
            folder_options+=("$icloud_docs/Personal Assistant")
            folder_labels+=("$MSG_PROFILE_ICLOUD_DOCS")
            option_num=$((option_num + 1))
        fi
        if [[ -d "$dropbox" ]]; then
            folder_options+=("$dropbox/Personal Assistant")
            folder_labels+=("$MSG_PROFILE_DROPBOX")
            option_num=$((option_num + 1))
        fi
        if [[ -d "$gdrive" ]]; then
            folder_options+=("$gdrive/Personal Assistant")
            folder_labels+=("$MSG_PROFILE_GDRIVE")
            option_num=$((option_num + 1))
        fi
        if [[ -d "$onedrive" ]]; then
            folder_options+=("$onedrive/Personal Assistant")
            folder_labels+=("$MSG_PROFILE_ONEDRIVE")
            option_num=$((option_num + 1))
        fi

        folder_options+=("$HOME/Documents/Personal Assistant")
        folder_labels+=("$MSG_PROFILE_LOCAL")
        option_num=$((option_num + 1))

        folder_options+=("custom")
        folder_labels+=("$MSG_PROFILE_CUSTOM")

        for i in "${!folder_labels[@]}"; do
            echo "    $((i+1)). ${folder_labels[$i]}"
        done
        echo ""

        ask_default "Choice:" "$default_choice" folder_choice

        local idx=$((folder_choice - 1))
        if [[ "${folder_options[$idx]}" == "custom" ]]; then
            ask "$MSG_PROFILE_ENTER_PATH" NOTES_FOLDER
        else
            NOTES_FOLDER="${folder_options[$idx]}"
        fi
    fi

    print_success "Timezone: $TIMEZONE"
    print_success "Notes folder: $NOTES_FOLDER"
}

# ─── Family Extension ──────────────────────────────────────────

collect_family() {
    print_step "$MSG_FAMILY_TITLE"

    if [[ "$ENABLE_FAMILY" == true ]]; then
        echo "  Current family setup: $FAMILY_NAME ($FAMILY_CHANNEL_ID)"
        echo ""
        if ! confirm_no "$MSG_FAMILY_CHANGE"; then
            print_success "$MSG_FAMILY_KEEPING"
            return
        fi
    fi

    if ! confirm "$MSG_FAMILY_CONFIRM"; then
        ENABLE_FAMILY=false
        return
    fi

    ENABLE_FAMILY=true
    local default_fname="${FAMILY_NAME:-}"
    if [[ -n "$default_fname" ]]; then
        ask_default "$MSG_FAMILY_NAME" "$default_fname" FAMILY_NAME
    else
        ask "$MSG_FAMILY_NAME" FAMILY_NAME
    fi
    ask_default "$MSG_FAMILY_CHANNEL" "${FAMILY_CHANNEL_ID:-}" FAMILY_CHANNEL_ID
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
    print_step "$MSG_GENERATING"

    mkdir -p "$NOTES_FOLDER"
    mkdir -p "$NOTES_FOLDER/reference"

    # Use language-specific framework directory
    local framework_src="$SCRIPT_DIR/framework/$LANG_CODE"
    if [[ ! -d "$framework_src" ]]; then
        framework_src="$SCRIPT_DIR/framework/en"
    fi

    # Baseline files go to reference/ (always overwritable)
    local baseline_files=(
        "START HERE.md"
        "Getting Started.md"
        "Cognitive Levels.md"
        "Priority Framework.md"
        "Cowork Agent Playbook.md"
    )

    # Template files go to root level (only if not already present)
    local template_files=(
        "Automations.md"
        "Grocery List.md"
    )

    # Copy baseline files to reference/ (always overwrite — these are upgradeable)
    for basename in "${baseline_files[@]}"; do
        local src="$framework_src/$basename"
        if [[ -f "$src" ]]; then
            cp "$src" "$NOTES_FOLDER/reference/$basename"
            print_success "reference/$basename"
        fi
    done

    # Copy template files to root level (only if not already present)
    for basename in "${template_files[@]}"; do
        local src="$framework_src/$basename"
        if [[ -f "$src" && ! -f "$NOTES_FOLDER/$basename" ]]; then
            cp "$src" "$NOTES_FOLDER/$basename"
            print_success "$basename"
        elif [[ -f "$NOTES_FOLDER/$basename" ]]; then
            print_warning "$basename $MSG_ALREADY_EXISTS"
        fi
    done

    # Also copy Travel Master List.md if it exists (optional template)
    if [[ -f "$framework_src/Travel Master List.md" && ! -f "$NOTES_FOLDER/Travel Master List.md" ]]; then
        cp "$framework_src/Travel Master List.md" "$NOTES_FOLDER/Travel Master List.md"
        print_success "Travel Master List.md"
    fi

    echo ""
    print_success "Framework files in: $NOTES_FOLDER"

    # Copy framework files for family member too
    if [[ "$ENABLE_FAMILY" == true && -n "$FAMILY_NOTES_FOLDER" ]]; then
        echo ""
        echo -e "  ${BOLD}Family: $FAMILY_NAME${NC}"
        mkdir -p "$FAMILY_NOTES_FOLDER"
        mkdir -p "$FAMILY_NOTES_FOLDER/reference"

        # Baseline to reference/
        for basename in "${baseline_files[@]}"; do
            local src="$framework_src/$basename"
            if [[ -f "$src" ]]; then
                cp "$src" "$FAMILY_NOTES_FOLDER/reference/$basename"
                print_success "reference/$basename"
            fi
        done

        # Templates to root
        for basename in "${template_files[@]}"; do
            local src="$framework_src/$basename"
            if [[ -f "$src" && ! -f "$FAMILY_NOTES_FOLDER/$basename" ]]; then
                cp "$src" "$FAMILY_NOTES_FOLDER/$basename"
                print_success "$basename"
            else
                print_warning "$basename $MSG_ALREADY_EXISTS"
            fi
        done

        # Create cross-tasks.json in data dir if needed
        local data_dir="$SCRIPT_DIR/data"
        mkdir -p "$data_dir"
        local cross_path="$data_dir/cross-tasks.json"
        if [[ ! -f "$cross_path" ]]; then
            echo '{"pending":[],"completed":[],"rejected":[]}' > "$cross_path"
            print_success "cross-tasks.json"
        fi

        print_success "Family files in: $FAMILY_NOTES_FOLDER"
    fi
}

# ─── Install Dependencies ──────────────────────────────────────

install_deps() {
    if [[ "$SETUP_MODE" != "daemon" ]]; then return; fi

    print_step "$MSG_DEPS_TITLE"

    local venv_dir="$SCRIPT_DIR/.venv"

    # Create venv if it doesn't exist
    if [[ ! -d "$venv_dir" ]]; then
        echo "  $MSG_RUN_CREATING_VENV"
        python3 -m venv "$venv_dir"
    fi
    print_success "Virtual environment: .venv/"

    # Install deps in venv
    if "$venv_dir/bin/pip" install -r "$SCRIPT_DIR/daemon/requirements.txt" --quiet 2>/dev/null; then
        print_success "$MSG_DEPS_INSTALLED"
    else
        print_warning "Could not install automatically. Run manually:"
        echo "    $venv_dir/bin/pip install -r $SCRIPT_DIR/daemon/requirements.txt"
    fi

    # Create/update .env
    local env_file="$NOTES_FOLDER/.env"
    echo "SLACK_BOT_TOKEN=$SLACK_BOT_TOKEN" > "$env_file"
    if [[ -n "$SLACK_APP_TOKEN" ]]; then
        echo "SLACK_APP_TOKEN=$SLACK_APP_TOKEN" >> "$env_file"
    fi
    print_success ".env updated (tokens stored)"
}

# ─── Create Scheduled Tasks (Cowork Mode) ──────────────────────

create_cowork_tasks() {
    if [[ "$SETUP_MODE" != "cowork" ]]; then return; fi

    print_step "Creating Scheduled Tasks"
    echo "  Cowork mode scheduled tasks are no longer supported."
    echo "  Please use Daemon mode instead."
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

    print_step "$MSG_DAEMON_TITLE"

    echo "    1. Background service (auto-starts on boot)"
    echo "    2. $MSG_DAEMON_MANUAL"
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
        echo "  $MSG_DAEMON_VERIFY"
        sleep 2

        if [[ "$(uname)" == "Darwin" ]]; then
            if launchctl list 2>/dev/null | grep -q "com.mission-control.daemon"; then
                print_success "$MSG_DAEMON_RUNNING"
            else
                print_warning "Daemon may not have started. Check logs:"
                echo "    cat $HOME/.mission-control.log"
                echo "    cat $HOME/.mission-control.err"
            fi
        else
            if systemctl --user is-active mission-control &>/dev/null; then
                print_success "$MSG_DAEMON_RUNNING"
            else
                print_warning "Daemon may not have started. Check:"
                echo "    systemctl --user status mission-control"
            fi
        fi

    else
        echo ""
        echo "  $MSG_DAEMON_MANUAL_START"
        echo "    cd $SCRIPT_DIR"
        echo "    ./run.sh"
        echo ""
        echo "  $MSG_DAEMON_MANUAL_VERIFY"
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
        <key>SLACK_APP_TOKEN</key>
        <string>$SLACK_APP_TOKEN</string>
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
Environment=SLACK_APP_TOKEN=$SLACK_APP_TOKEN
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
            print_step "$MSG_RESTART_TITLE"
            echo "  $MSG_RESTART_DETECTED"
            launchctl stop com.mission-control.daemon 2>/dev/null || true
            sleep 1
            launchctl start com.mission-control.daemon 2>/dev/null || true
            print_success "$MSG_RESTART_DONE"
        fi
    else
        if systemctl --user is-active mission-control &>/dev/null; then
            was_running=true
            print_step "$MSG_RESTART_TITLE"
            echo "  $MSG_RESTART_DETECTED"
            systemctl --user restart mission-control 2>/dev/null || true
            print_success "$MSG_RESTART_DONE"
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
    echo -e "  ${BOLD}║   $MSG_SUMMARY_COMPLETE${NC}"
    echo -e "  ${BOLD}╚═══════════════════════════════════════════╝${NC}"
    echo ""
    echo "  Assistant: $ASSISTANT_NAME"
    echo "  Folder:    $NOTES_FOLDER"
    echo "  Channel:   $SLACK_CHANNEL_NAME"
    echo ""
    if [[ "$SETUP_MODE" == "daemon" ]]; then
        echo "  $MSG_SUMMARY_NEXT"
        echo "    1. $MSG_SUMMARY_NEXT1"
        echo "    2. $MSG_SUMMARY_NEXT2 $SLACK_CHANNEL_NAME"
        echo "       $MSG_SUMMARY_NEXT3"
        echo "    3. $MSG_SUMMARY_NEXT4"
        echo "       $MSG_SUMMARY_NEXT5"
        echo ""
        echo "  $MSG_SUMMARY_COMMANDS"
        echo "    View logs:  tail -f ~/.mission-control.log"
        echo "    Test run:   cd $SCRIPT_DIR && ./run.sh --once"
        echo "    Status:     cd $SCRIPT_DIR && ./status.sh"
        echo "    Re-setup:   ./setup.sh"
    fi
    echo ""
    echo -e "  ${DIM}$MSG_SUMMARY_LOG $LOG_FILE${NC}"
    echo -e "  ${DIM}$MSG_SUMMARY_LOG_HINT${NC}"
    echo ""
    echo -e "  ${GREEN}$MSG_SUMMARY_ENJOY${NC}"
    echo ""
}

# ─── Main ──────────────────────────────────────────────────────

main() {
    parse_args "$@"
    collect_language
    show_banner
    detect_existing
    check_system
    collect_mode
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
