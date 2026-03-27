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
    [[ -z "${!var}" ]] && eval "$var='$default'"
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

        echo "  How would you like to run Mission Control?"
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
    echo "  Let's create a Slack App so Mission Control can read and post messages."
    echo "  I'll walk you through each step."
    echo ""

    # Step 1: Create App
    echo -e "  ${BOLD}Step 1/5: Create a Slack App${NC}"
    echo "    → Opening Slack App creation page..."
    open_url "https://api.slack.com/apps?new_app=1"
    echo "    → Choose 'From scratch'"
    echo "    → Name: 'Mission Control'"
    echo "    → Select your workspace"
    echo ""
    confirm "Done?" || true

    # Step 2: Bot Permissions
    echo ""
    echo -e "  ${BOLD}Step 2/5: Add Bot Permissions${NC}"
    echo "    → In your new app, go to 'OAuth & Permissions' (left sidebar)"
    echo "    → Scroll to 'Bot Token Scopes'"
    echo "    → Add these scopes:"
    echo "      • channels:history  (read messages)"
    echo "      • channels:read     (see channel info)"
    echo "      • chat:write        (post messages)"
    echo "      • reactions:read    (see reactions)"
    echo ""
    confirm "Done?" || true

    # Step 3: Install
    echo ""
    echo -e "  ${BOLD}Step 3/5: Install to Workspace${NC}"
    echo "    → Click 'Install to Workspace' at the top of OAuth & Permissions"
    echo "    → Click 'Allow'"
    echo ""
    confirm "Done?" || true

    # Step 4: Copy Token
    echo ""
    echo -e "  ${BOLD}Step 4/5: Copy Bot Token${NC}"
    echo "    → You should see 'Bot User OAuth Token' (starts with xoxb-)"
    echo ""
    ask "Paste your Bot Token:" SLACK_BOT_TOKEN

    if [[ ! "$SLACK_BOT_TOKEN" =~ ^xoxb- ]]; then
        print_warning "Token doesn't start with 'xoxb-' — make sure you copied the Bot token, not the User token"
    fi

    # Step 5: Channel
    echo ""
    echo -e "  ${BOLD}Step 5/5: Set Up Channel${NC}"
    echo "    → Create a channel in Slack (e.g., #my-cowork) or use an existing one"
    echo "    → Invite the bot: type /invite @Mission Control in the channel"
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
    ask_default "Notes folder:" "$HOME/Documents/Mission Control" NOTES_FOLDER

    print_success "Profile: $USER_NAME | $TIMEZONE"
}

# ─── Step 7: Schedule ───────────────────────────────────────────────

collect_schedule() {
    print_step "Step 7: Daily Schedule"

    echo "  All times in 24h format (e.g., 07:30)"
    echo ""

    ask_default "Wake time:" "07:30" WAKE_TIME
    ask_default "Sleep time:" "23:00" SLEEP_TIME
    ask_default "Work hours start:" "09:00" WORK_START
    ask_default "Work hours end:" "17:00" WORK_END

    # Deep work blocks
    echo ""
    echo "  Deep work blocks (up to 3, press Enter to finish):"
    DEEP_WORK_BLOCKS=""
    local block_num=1
    while [[ $block_num -le 3 ]]; do
        local block_start
        ask "  Block $block_num start (or Enter to finish):" block_start
        [[ -z "$block_start" ]] && break
        local block_end
        ask "  Block $block_num end:" block_end
        DEEP_WORK_BLOCKS="${DEEP_WORK_BLOCKS}- **${block_start}-${block_end}** — Deep work block $block_num
"
        ((block_num++))
    done
    [[ -z "$DEEP_WORK_BLOCKS" ]] && DEEP_WORK_BLOCKS="- **${WORK_START}-${WORK_END}** — Main work block
"

    # Fixed commitments
    echo ""
    echo "  Fixed daily commitments (press Enter to finish):"
    FIXED_COMMITMENTS=""
    while true; do
        local commitment
        ask "  Commitment (or Enter to finish):" commitment
        [[ -z "$commitment" ]] && break
        FIXED_COMMITMENTS="${FIXED_COMMITMENTS}- ${commitment}
"
    done
    [[ -z "$FIXED_COMMITMENTS" ]] && FIXED_COMMITMENTS="_(none configured)_
"

    # Off-limits times
    echo ""
    echo "  Off-limits times — no notifications (press Enter to finish):"
    OFF_LIMITS=""
    while true; do
        local period
        ask "  Off-limits period (or Enter to finish):" period
        [[ -z "$period" ]] && break
        OFF_LIMITS="${OFF_LIMITS}- ${period}
"
    done
    [[ -z "$OFF_LIMITS" ]] && OFF_LIMITS="_(none configured)_
"

    print_success "Schedule configured"
}

# ─── Step 8: Workstreams ────────────────────────────────────────────

collect_workstreams() {
    print_step "Step 8: Workstreams"

    echo "  Add your projects (1-6). Press Enter to finish."
    echo ""

    WORKSTREAM_COUNT=0
    WORKSTREAM_NAMES=()
    WORKSTREAM_PRIORITIES=()
    WORKSTREAM_PHASES=()
    WORKSTREAM_LEVELS=()

    while [[ $WORKSTREAM_COUNT -lt 6 ]]; do
        local num=$((WORKSTREAM_COUNT + 1))
        local ws_name
        ask "Workstream $num name (or Enter to finish):" ws_name
        [[ -z "$ws_name" ]] && break

        local ws_priority ws_phase ws_level
        ask_default "  Priority (1=highest):" "$num" ws_priority
        ask_default "  Phase (planning/active/maintenance):" "active" ws_phase
        ask_default "  Cognitive level (L1/L2/L3/L1-L2):" "L1-L2" ws_level
        echo ""

        WORKSTREAM_NAMES+=("$ws_name")
        WORKSTREAM_PRIORITIES+=("$ws_priority")
        WORKSTREAM_PHASES+=("$ws_phase")
        WORKSTREAM_LEVELS+=("$ws_level")
        ((WORKSTREAM_COUNT++))
    done

    if [[ $WORKSTREAM_COUNT -eq 0 ]]; then
        print_warning "No workstreams added. Creating 'General'."
        WORKSTREAM_NAMES=("General")
        WORKSTREAM_PRIORITIES=("1")
        WORKSTREAM_PHASES=("active")
        WORKSTREAM_LEVELS=("L1-L2")
        WORKSTREAM_COUNT=1
    fi

    WORKSTREAM_PRIORITY_ORDER=""
    for name in "${WORKSTREAM_NAMES[@]}"; do
        [[ -n "$WORKSTREAM_PRIORITY_ORDER" ]] && WORKSTREAM_PRIORITY_ORDER+=" > "
        WORKSTREAM_PRIORITY_ORDER+="$name"
    done

    print_success "Workstreams: $WORKSTREAM_PRIORITY_ORDER"
}

# ─── Step 9: Features ───────────────────────────────────────────────

collect_features() {
    print_step "Step 9: Features"

    echo "  Select which features to enable:"
    echo ""

    ENABLE_DISPATCH=false; ENABLE_MIDDAY=false; ENABLE_AFTERNOON=false
    ENABLE_EOD=false; ENABLE_WEEKLY_REVIEW=false; ENABLE_WEEKLY_PLAN=false
    ENABLE_GROCERY=false; ENABLE_TRAVEL=false

    DISPATCH_TIME="08:00"; MIDDAY_TIME="12:30"; AFTERNOON_TIME="15:30"
    EOD_TIME="19:00"; WEEKLY_PLAN_TIME="20:00"

    if confirm "Morning dispatch?"; then
        ENABLE_DISPATCH=true
        ask_default "  Time:" "08:00" DISPATCH_TIME
    fi
    if confirm "Midday check-in?"; then
        ENABLE_MIDDAY=true
        ask_default "  Time:" "12:30" MIDDAY_TIME
    fi
    if confirm "Afternoon check-in?"; then
        ENABLE_AFTERNOON=true
        ask_default "  Time:" "15:30" AFTERNOON_TIME
    fi
    if confirm "End-of-day summary?"; then
        ENABLE_EOD=true
        ask_default "  Time:" "19:00" EOD_TIME
    fi
    if confirm "Friday weekly review?"; then ENABLE_WEEKLY_REVIEW=true; fi
    if confirm "Sunday weekly planning?"; then
        ENABLE_WEEKLY_PLAN=true
        ask_default "  Time:" "20:00" WEEKLY_PLAN_TIME
    fi
    echo ""
    if confirm "Grocery list management?"; then ENABLE_GROCERY=true; fi
    if confirm "Travel packing list?"; then ENABLE_TRAVEL=true; fi

    print_success "Features configured"
}

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
    ask_default "Their notes folder:" "$(dirname "$NOTES_FOLDER")/Mission Control - $FAMILY_NAME" FAMILY_NOTES_FOLDER

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
    do_sed "s|{{WAKE_TIME}}|${WAKE_TIME}|g" "$file"
    do_sed "s|{{SLEEP_TIME}}|${SLEEP_TIME}|g" "$file"
    do_sed "s|{{WORK_START}}|${WORK_START}|g" "$file"
    do_sed "s|{{WORK_END}}|${WORK_END}|g" "$file"
    do_sed "s|{{DISPATCH_TIME}}|${DISPATCH_TIME}|g" "$file"
    do_sed "s|{{MIDDAY_TIME}}|${MIDDAY_TIME}|g" "$file"
    do_sed "s|{{AFTERNOON_TIME}}|${AFTERNOON_TIME}|g" "$file"
    do_sed "s|{{EOD_TIME}}|${EOD_TIME}|g" "$file"
    do_sed "s|{{WEEKLY_PLAN_TIME}}|${WEEKLY_PLAN_TIME}|g" "$file"
    do_sed "s|{{WORKSTREAM_PRIORITY_ORDER}}|${WORKSTREAM_PRIORITY_ORDER}|g" "$file"
    if [[ "$ENABLE_FAMILY" == true ]]; then
        do_sed "s|{{FAMILY_NAME}}|${FAMILY_NAME}|g" "$file"
        do_sed "s|{{CROSS_TASKS_PATH}}|$(dirname "$NOTES_FOLDER")/cross-tasks.json|g" "$file"
    fi
}

replace_block() {
    local file="$1" placeholder="$2" content="$3"
    local tmpf
    tmpf=$(mktemp)
    printf '%s' "$content" > "$tmpf"
    if grep -q "$placeholder" "$file" 2>/dev/null; then
        do_sed "/$placeholder/r $tmpf" "$file"
        do_sed "/$placeholder/d" "$file"
    fi
    rm -f "$tmpf"
}

apply_conditionals() {
    local file="$1"
    for feat_pair in "GROCERY:$ENABLE_GROCERY" "TRAVEL:$ENABLE_TRAVEL" "FAMILY:$ENABLE_FAMILY"; do
        local feat="${feat_pair%%:*}"
        local enabled="${feat_pair##*:}"
        if [[ "$enabled" == true ]]; then
            do_sed "/{{#${feat}}}/d; /{{\\/${feat}}}/d" "$file"
        else
            perl -i -0pe "s/\\{\\{#${feat}\\}\\}.*?\\{\\{\\/${feat}\\}\\}\\n?//gs" "$file"
        fi
    done
}

generate_files() {
    print_step "Step 11: Generating Files"

    mkdir -p "$NOTES_FOLDER/skills/mission-control"

    local core_tpl="$SCRIPT_DIR/templates/core/$LANG_CODE"
    local prompt_tpl="$SCRIPT_DIR/templates/prompts/$LANG_CODE"

    # Build dynamic content
    local schedule_table="| Time | Block | Capacity |
|------|-------|----------|
| ${WAKE_TIME}-${WORK_START} | Morning routine | L3 only |
| ${WORK_START}-${WORK_END} | Work hours | L1/L2/L3 |
| ${WORK_END}-${SLEEP_TIME} | Evening | Variable |"

    local schedule_summary="- Work hours: ${WORK_START}-${WORK_END}
- Deep work blocks configured in Daily Scaffolding.md"

    local current_week
    current_week=$(python3 -c "from datetime import date; d=date.today(); print(f'{d.year}-W{d.isocalendar()[1]:02d}')" 2>/dev/null || echo "Current Week")

    # Generate workstream sections
    local ws_sections=""
    for i in $(seq 0 $((WORKSTREAM_COUNT - 1))); do
        local num=$((i + 1))
        ws_sections="${ws_sections}## ${num}. ${WORKSTREAM_NAMES[$i]}
- **Phase:** ${WORKSTREAM_PHASES[$i]}
- **Cognitive Level:** ${WORKSTREAM_LEVELS[$i]}
- **Status:** In progress
- **Next Milestone:** _(set during weekly planning)_
- **Pick-Up Packet:**
  - _(Add context here for resuming this workstream)_
- **Decisions Log:**
  - _(Record key decisions)_

### Pending Tasks
_(Add tasks: **[LX] Task name** — details)_

### Completed
_(Format: **[LX] Task name** — Done YYYY-MM-DD)_

---

"
    done

    # Weekly goals sections
    local wg_sections=""
    for i in $(seq 0 $((WORKSTREAM_COUNT - 1))); do
        wg_sections="${wg_sections}### ${WORKSTREAM_NAMES[$i]}
**P1 — Must Do:**
- [ ] _(add goals during weekly planning)_

**P2 — Should Do:**
- [ ] _(add goals during weekly planning)_

"
    done

    # Grocery sections
    local grocery_sections="## Bulk Store (Costco / Sam's Club)
_(empty)_

## Regular Grocery
_(empty)_

## Specialty Grocery
_(empty)_

## Store-Specific Requests
_(empty)_"

    local grocery_rules="**Bulk Store**: cleaning supplies, paper goods, bulk items
**Specialty Grocery**: specialty sauces, ethnic ingredients
**Regular Grocery** (default): fresh produce, dairy, meat, pantry staples"

    # ── Copy and process files ──

    cp "$core_tpl/cognitive-levels.md" "$NOTES_FOLDER/Cognitive Levels.md"
    print_success "Cognitive Levels.md"

    cp "$core_tpl/priority-framework.md" "$NOTES_FOLDER/Priority Framework.md"
    print_success "Priority Framework.md"

    # Daily Scaffolding
    cp "$core_tpl/daily-scaffolding.md.tpl" "$NOTES_FOLDER/Daily Scaffolding.md"
    replace_block "$NOTES_FOLDER/Daily Scaffolding.md" "{{SCHEDULE_TABLE}}" "$schedule_table"
    replace_block "$NOTES_FOLDER/Daily Scaffolding.md" "{{FIXED_COMMITMENTS}}" "$FIXED_COMMITMENTS"
    replace_block "$NOTES_FOLDER/Daily Scaffolding.md" "{{DEEP_WORK_BLOCKS}}" "$DEEP_WORK_BLOCKS"
    replace_block "$NOTES_FOLDER/Daily Scaffolding.md" "{{OFF_LIMITS}}" "$OFF_LIMITS"
    apply_substitutions "$NOTES_FOLDER/Daily Scaffolding.md"
    print_success "Daily Scaffolding.md"

    # Workstreams
    cp "$core_tpl/workstreams.md.tpl" "$NOTES_FOLDER/Workstreams.md"
    replace_block "$NOTES_FOLDER/Workstreams.md" "{{WORKSTREAM_SECTIONS}}" "$ws_sections"
    apply_substitutions "$NOTES_FOLDER/Workstreams.md"
    print_success "Workstreams.md"

    # Weekly Goals
    cp "$core_tpl/weekly-goals.md.tpl" "$NOTES_FOLDER/Weekly Goals.md"
    replace_block "$NOTES_FOLDER/Weekly Goals.md" "{{WEEKLY_GOALS_SECTIONS}}" "$wg_sections"
    do_sed "s|{{CURRENT_WEEK_LABEL}}|${current_week}|g" "$NOTES_FOLDER/Weekly Goals.md"
    apply_substitutions "$NOTES_FOLDER/Weekly Goals.md"
    print_success "Weekly Goals.md"

    # Grocery (optional)
    if [[ "$ENABLE_GROCERY" == true ]]; then
        cp "$core_tpl/grocery-list.md.tpl" "$NOTES_FOLDER/Grocery List.md"
        replace_block "$NOTES_FOLDER/Grocery List.md" "{{GROCERY_SECTIONS}}" "$grocery_sections"
        replace_block "$NOTES_FOLDER/Grocery List.md" "{{GROCERY_RULES}}" "$grocery_rules"
        apply_substitutions "$NOTES_FOLDER/Grocery List.md"
        print_success "Grocery List.md"
    fi

    # Travel (optional)
    if [[ "$ENABLE_TRAVEL" == true ]]; then
        cp "$core_tpl/travel-master-list.md" "$NOTES_FOLDER/Travel Master List.md"
        print_success "Travel Master List.md"
    fi

    # Reminders
    if [[ ! -f "$NOTES_FOLDER/reminders.json" ]]; then
        echo "[]" > "$NOTES_FOLDER/reminders.json"
        print_success "reminders.json"
    fi

    # Playbook
    cp "$prompt_tpl/playbook.md.tpl" "$NOTES_FOLDER/Cowork Agent Playbook.md"
    apply_substitutions "$NOTES_FOLDER/Cowork Agent Playbook.md"
    print_success "Cowork Agent Playbook.md"

    # SKILL.md (system prompt)
    cp "$prompt_tpl/system-prompt.md.tpl" "$NOTES_FOLDER/skills/mission-control/SKILL.md"
    apply_substitutions "$NOTES_FOLDER/skills/mission-control/SKILL.md"
    apply_conditionals "$NOTES_FOLDER/skills/mission-control/SKILL.md"
    replace_block "$NOTES_FOLDER/skills/mission-control/SKILL.md" "{{SCHEDULE_SUMMARY}}" "$schedule_summary"
    print_success "skills/mission-control/SKILL.md"

    print_success "All state files generated in: $NOTES_FOLDER"
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
            mc-morning-dispatch) [[ "$ENABLE_DISPATCH" != true ]] && continue ;;
            mc-midday-checkin)   [[ "$ENABLE_MIDDAY" != true ]] && continue ;;
            mc-afternoon-checkin) [[ "$ENABLE_AFTERNOON" != true ]] && continue ;;
            mc-eod-summary)      [[ "$ENABLE_EOD" != true ]] && continue ;;
            mc-friday-summary)   [[ "$ENABLE_WEEKLY_REVIEW" != true ]] && continue ;;
            mc-sunday-planning)  [[ "$ENABLE_WEEKLY_PLAN" != true ]] && continue ;;
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
  "wake_time": "$WAKE_TIME",
  "sleep_time": "$SLEEP_TIME",
  "work_start": "$WORK_START",
  "work_end": "$WORK_END",
  "features": {
    "dispatch": $ENABLE_DISPATCH,
    "midday": $ENABLE_MIDDAY,
    "afternoon": $ENABLE_AFTERNOON,
    "eod": $ENABLE_EOD,
    "weekly_review": $ENABLE_WEEKLY_REVIEW,
    "weekly_plan": $ENABLE_WEEKLY_PLAN,
    "grocery": $ENABLE_GROCERY,
    "travel": $ENABLE_TRAVEL,
    "family": $ENABLE_FAMILY
  },
  "dispatch_time": "$DISPATCH_TIME",
  "midday_time": "$MIDDAY_TIME",
  "afternoon_time": "$AFTERNOON_TIME",
  "eod_time": "$EOD_TIME",
  "weekly_plan_time": "$WEEKLY_PLAN_TIME",
  "workstream_count": $WORKSTREAM_COUNT,
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
Description=Mission Control Daemon
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

    if [[ "$SETUP_MODE" == "daemon" ]]; then
        echo "  Next steps:"
        echo "    1. Check your Slack channel for a welcome message"
        echo "    2. Open your notes folder in Obsidian (or any editor)"
        echo "    3. Customize Workstreams.md and Daily Scaffolding.md"
        echo "    4. Send a message in Slack: 'what should I work on?'"
    else
        echo "  Next steps:"
        echo "    1. Open Claude Desktop → Schedule tab"
        echo "    2. Configure timing for each mc-* task"
        echo "    3. Open your notes folder in Obsidian"
        echo "    4. Start a Claude session: 'Run my morning dispatch'"
    fi

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
    collect_schedule
    collect_workstreams
    collect_features
    collect_family
    generate_files
    install_deps
    create_cowork_tasks
    save_config
    setup_daemon_service
    print_summary
}

main "$@"
