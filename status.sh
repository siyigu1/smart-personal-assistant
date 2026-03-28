#!/usr/bin/env bash
# Personal Assistant — Status Dashboard
#
# Usage:
#   ./status.sh              # Overview: running? last activity? errors?
#   ./status.sh activity     # Recent activity log (last 20 entries)
#   ./status.sh activity 50  # Last 50 entries
#   ./status.sh llm          # Recent LLM calls with details
#   ./status.sh errors       # Recent errors only
#   ./status.sh full         # Full activity log (last 100 entries)

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
LOG_DIR="$SCRIPT_DIR/logs"
ACTIVITY_FILE="$LOG_DIR/activity.jsonl"

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m'
BOLD='\033[1m'
DIM='\033[2m'

# ─── Helpers ────────────────────────────────────────────────────

check_running() {
    if [[ "$(uname)" == "Darwin" ]]; then
        if launchctl list 2>/dev/null | grep -q "com.mission-control.daemon"; then
            echo -e "  ${GREEN}●${NC} Daemon is ${GREEN}running${NC} (launchd)"
        else
            echo -e "  ${RED}●${NC} Daemon is ${RED}not running${NC}"
            echo -e "  ${DIM}  Start with: ./run.sh${NC}"
        fi
    else
        if systemctl --user is-active mission-control &>/dev/null; then
            echo -e "  ${GREEN}●${NC} Daemon is ${GREEN}running${NC} (systemd)"
        else
            echo -e "  ${RED}●${NC} Daemon is ${RED}not running${NC}"
            echo -e "  ${DIM}  Start with: ./run.sh${NC}"
        fi
    fi
}

format_entry() {
    local line="$1"
    local ts action detail
    ts=$(echo "$line" | python3 -c "import json,sys; e=json.load(sys.stdin); print(e.get('ts','')[:19])" 2>/dev/null || echo "?")
    action=$(echo "$line" | python3 -c "import json,sys; e=json.load(sys.stdin); print(e.get('action',''))" 2>/dev/null || echo "?")
    detail=$(echo "$line" | python3 -c "import json,sys; e=json.load(sys.stdin); print(e.get('detail',''))" 2>/dev/null || echo "?")

    local color="$NC"
    local icon="  "
    case "$action" in
        startup)         color="$GREEN"; icon="▶ " ;;
        shutdown)        color="$RED";   icon="■ " ;;
        poll)            color="$DIM";   icon="  " ;;
        reminder)        color="$YELLOW"; icon="⏰" ;;
        automation)      color="$BLUE";  icon="⚡" ;;
        automation_skip) color="$DIM";   icon="  " ;;
        llm_call)        color="$GREEN"; icon="🤖" ;;
        llm_error)       color="$RED";   icon="❌" ;;
        error)           color="$RED";   icon="❌" ;;
        onboarding)      color="$GREEN"; icon="👋" ;;
        *)               icon="  " ;;
    esac

    # Skip "no new messages" polls in non-full mode
    if [[ "${SHOW_POLLS:-false}" == "false" && "$action" == "poll" && "$detail" == "No new messages" ]]; then
        return
    fi

    echo -e "  ${DIM}${ts}${NC}  ${icon} ${color}${detail}${NC}"
}

# ─── Commands ───────────────────────────────────────────────────

show_overview() {
    echo ""
    echo -e "${BOLD}Personal Assistant — Status${NC}"
    echo ""

    # Running status
    check_running
    echo ""

    # Last activity
    if [[ ! -f "$ACTIVITY_FILE" ]]; then
        echo -e "  ${DIM}No activity log found. Has the daemon run yet?${NC}"
        return
    fi

    # Last startup
    local last_start
    last_start=$(grep '"startup"' "$ACTIVITY_FILE" 2>/dev/null | tail -1 || echo "")
    if [[ -n "$last_start" ]]; then
        local start_ts
        start_ts=$(echo "$last_start" | python3 -c "import json,sys; print(json.load(sys.stdin).get('ts','')[:19])" 2>/dev/null || echo "?")
        echo -e "  Last started: ${BOLD}$start_ts${NC}"
    fi

    # Last poll
    local last_poll
    last_poll=$(grep '"poll"' "$ACTIVITY_FILE" 2>/dev/null | tail -1 || echo "")
    if [[ -n "$last_poll" ]]; then
        local poll_ts
        poll_ts=$(echo "$last_poll" | python3 -c "import json,sys; print(json.load(sys.stdin).get('ts','')[:19])" 2>/dev/null || echo "?")
        echo -e "  Last poll:    ${BOLD}$poll_ts${NC}"
    fi

    echo ""

    # Today's stats
    local today
    today=$(date +%Y-%m-%d)
    local total_polls llm_calls reminders_fired errors
    total_polls=$(grep -c "\"poll\"" "$ACTIVITY_FILE" 2>/dev/null | grep "$today" || grep "$today" "$ACTIVITY_FILE" 2>/dev/null | grep -c '"poll"' || echo 0)
    llm_calls=$(grep "$today" "$ACTIVITY_FILE" 2>/dev/null | grep -c '"llm_call"' || echo 0)
    reminders_fired=$(grep "$today" "$ACTIVITY_FILE" 2>/dev/null | grep -c '"reminder"' || echo 0)
    errors=$(grep "$today" "$ACTIVITY_FILE" 2>/dev/null | grep -c '"error"\|"llm_error"' || echo 0)

    echo -e "  ${BOLD}Today:${NC}"
    echo -e "    Polls: $total_polls  |  LLM calls: $llm_calls  |  Reminders: $reminders_fired  |  Errors: $errors"
    echo ""

    # Recent significant activity (skip empty polls)
    echo -e "  ${BOLD}Recent activity:${NC}"
    SHOW_POLLS=false
    tail -50 "$ACTIVITY_FILE" 2>/dev/null | while IFS= read -r line; do
        format_entry "$line"
    done | tail -10
    echo ""

    # Log disk usage
    local log_size
    log_size=$(du -sh "$LOG_DIR" 2>/dev/null | awk '{print $1}' || echo "?")
    echo -e "  ${DIM}Log dir: $LOG_DIR ($log_size)${NC}"
    echo -e "  ${DIM}Logs auto-cleanup: 7 days${NC}"
    echo ""
}

show_activity() {
    local count="${1:-20}"
    echo ""
    echo -e "${BOLD}Recent Activity (last $count entries)${NC}"
    echo ""

    if [[ ! -f "$ACTIVITY_FILE" ]]; then
        echo "  No activity log found."
        return
    fi

    SHOW_POLLS=false
    tail -"$count" "$ACTIVITY_FILE" 2>/dev/null | while IFS= read -r line; do
        format_entry "$line"
    done
    echo ""
}

show_llm() {
    echo ""
    echo -e "${BOLD}Recent LLM Calls${NC}"
    echo ""

    if [[ ! -f "$ACTIVITY_FILE" ]]; then
        echo "  No activity log found."
        return
    fi

    grep '"llm_call"\|"llm_error"' "$ACTIVITY_FILE" 2>/dev/null | tail -20 | while IFS= read -r line; do
        local ts action detail duration operation
        ts=$(echo "$line" | python3 -c "import json,sys; e=json.load(sys.stdin); print(e.get('ts','')[:19])" 2>/dev/null)
        action=$(echo "$line" | python3 -c "import json,sys; e=json.load(sys.stdin); print(e.get('action',''))" 2>/dev/null)
        detail=$(echo "$line" | python3 -c "import json,sys; e=json.load(sys.stdin); print(e.get('detail',''))" 2>/dev/null)
        operation=$(echo "$line" | python3 -c "import json,sys; print(json.load(sys.stdin).get('extra',{}).get('operation',''))" 2>/dev/null)
        duration=$(echo "$line" | python3 -c "import json,sys; print(json.load(sys.stdin).get('extra',{}).get('duration_sec',''))" 2>/dev/null)
        preview=$(echo "$line" | python3 -c "import json,sys; print(json.load(sys.stdin).get('extra',{}).get('response_preview','')[:100])" 2>/dev/null)

        if [[ "$action" == "llm_error" ]]; then
            echo -e "  ${DIM}$ts${NC}  ${RED}❌ $detail${NC}"
        else
            echo -e "  ${DIM}$ts${NC}  ${GREEN}🤖${NC} ${BOLD}$operation${NC} (${duration}s)"
            if [[ -n "$preview" ]]; then
                echo -e "    ${DIM}$preview${NC}"
            fi
        fi
    done
    echo ""
}

show_errors() {
    echo ""
    echo -e "${BOLD}Recent Errors${NC}"
    echo ""

    if [[ ! -f "$ACTIVITY_FILE" ]]; then
        echo "  No activity log found."
        return
    fi

    local error_lines
    error_lines=$(grep '"error"\|"llm_error"' "$ACTIVITY_FILE" 2>/dev/null | tail -20)

    if [[ -z "$error_lines" ]]; then
        echo -e "  ${GREEN}No errors found.${NC}"
    else
        echo "$error_lines" | while IFS= read -r line; do
            SHOW_POLLS=true format_entry "$line"
        done
    fi
    echo ""
}

show_full() {
    local count="${1:-100}"
    echo ""
    echo -e "${BOLD}Full Activity Log (last $count entries)${NC}"
    echo ""

    if [[ ! -f "$ACTIVITY_FILE" ]]; then
        echo "  No activity log found."
        return
    fi

    SHOW_POLLS=true
    tail -"$count" "$ACTIVITY_FILE" 2>/dev/null | while IFS= read -r line; do
        format_entry "$line"
    done
    echo ""
}

# ─── Main ──────────────────────────────────────────────────────

case "${1:-}" in
    activity) show_activity "${2:-20}" ;;
    llm)      show_llm ;;
    errors)   show_errors ;;
    full)     show_full "${2:-100}" ;;
    --help|-h)
        echo "Usage: ./status.sh [command]"
        echo ""
        echo "  (none)        Overview: running status, today's stats, recent activity"
        echo "  activity [N]  Recent activity (default: last 20, skips empty polls)"
        echo "  llm           Recent LLM calls with operation, duration, preview"
        echo "  errors        Recent errors only"
        echo "  full [N]      Full log including empty polls (default: last 100)"
        ;;
    *)        show_overview ;;
esac
