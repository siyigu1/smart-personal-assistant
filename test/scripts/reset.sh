#!/usr/bin/env bash
# Reset everything for a fresh test. Run from the repo root.
#
# Usage:
#   ./test/scripts/reset.sh                    # Interactive — asks before deleting
#   ./test/scripts/reset.sh --force             # No prompts, delete everything
#   ./test/scripts/reset.sh --keep-config       # Keep .mc-config.json, reset everything else

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BOLD='\033[1m'
NC='\033[0m'

FORCE=false
KEEP_CONFIG=false

for arg in "$@"; do
    case $arg in
        --force) FORCE=true ;;
        --keep-config) KEEP_CONFIG=true ;;
    esac
done

confirm() {
    if [[ "$FORCE" == true ]]; then return 0; fi
    local ans
    read -rp "$(echo -e "  ${BOLD}$1${NC} [y/N] ")" ans
    [[ "$ans" =~ ^[Yy] ]]
}

echo ""
echo -e "${BOLD}Smart Personal Assistant — Reset${NC}"
echo ""

# 1. Stop running daemon
echo -e "${YELLOW}Stopping daemon...${NC}"
if [[ "$(uname)" == "Darwin" ]]; then
    launchctl stop com.mission-control.daemon 2>/dev/null || true
    launchctl unload ~/Library/LaunchAgents/com.mission-control.daemon.plist 2>/dev/null || true
    rm -f ~/Library/LaunchAgents/com.mission-control.daemon.plist
else
    systemctl --user stop mission-control 2>/dev/null || true
    systemctl --user disable mission-control 2>/dev/null || true
fi
# Kill any foreground run.sh
pkill -f "daemon.main" 2>/dev/null || true
echo -e "  ${GREEN}✓${NC} Daemon stopped"

# 2. Delete daemon data
if [[ -d "$REPO_DIR/data" ]]; then
    echo ""
    echo -e "${YELLOW}Daemon data:${NC} $REPO_DIR/data/"
    ls -la "$REPO_DIR/data/" 2>/dev/null || true
    if confirm "Delete daemon data (automations, memory, conversation state)?"; then
        rm -rf "$REPO_DIR/data"
        echo -e "  ${GREEN}✓${NC} Daemon data deleted"
    fi
fi

# 3. Delete logs
if [[ -d "$REPO_DIR/logs" ]]; then
    echo ""
    echo -e "${YELLOW}Logs:${NC} $REPO_DIR/logs/"
    du -sh "$REPO_DIR/logs/" 2>/dev/null || true
    if confirm "Delete logs?"; then
        rm -rf "$REPO_DIR/logs"
        echo -e "  ${GREEN}✓${NC} Logs deleted"
    fi
fi

# 4. Delete venv
if [[ -d "$REPO_DIR/.venv" ]]; then
    echo ""
    echo -e "${YELLOW}Virtual environment:${NC} $REPO_DIR/.venv/"
    if confirm "Delete .venv (will be recreated on next run)?"; then
        rm -rf "$REPO_DIR/.venv"
        echo -e "  ${GREEN}✓${NC} Virtual environment deleted"
    fi
fi

# 5. Find and optionally delete user notes folder
echo ""
echo -e "${YELLOW}Looking for user notes folders...${NC}"
found_folders=()
for candidate in \
    "$HOME/Library/Mobile Documents/iCloud~md~obsidian/Documents/Personal Assistant" \
    "$HOME/Library/Mobile Documents/com~apple~CloudDocs/Documents/Personal Assistant" \
    "$HOME/Documents/Personal Assistant" \
    "$HOME/Dropbox/Personal Assistant" \
    "$HOME/Google Drive/Personal Assistant" \
    "$HOME/OneDrive/Personal Assistant"; do
    if [[ -d "$candidate" ]]; then
        found_folders+=("$candidate")
    fi
done

# Also search by config
if [[ "$KEEP_CONFIG" == false ]]; then
    for cfg in $(find "$HOME" -name ".mc-config.json" -maxdepth 5 2>/dev/null); do
        folder=$(dirname "$cfg")
        already=false
        for f in "${found_folders[@]+"${found_folders[@]}"}"; do
            if [[ "$f" == "$folder" ]]; then already=true; break; fi
        done
        if [[ "$already" == false ]]; then
            found_folders+=("$folder")
        fi
    done
fi

for folder in "${found_folders[@]+"${found_folders[@]}"}"; do
    echo ""
    echo -e "  ${BOLD}$folder${NC}"
    ls "$folder"/*.md 2>/dev/null | head -5 || true
    if confirm "Delete this notes folder?"; then
        rm -rf "$folder"
        echo -e "  ${GREEN}✓${NC} Deleted"
    else
        echo -e "  ${YELLOW}!${NC} Kept"
    fi
done

# 6. Delete config
if [[ "$KEEP_CONFIG" == false ]]; then
    echo ""
    for cfg in $(find "$HOME" -name ".mc-config.json" -maxdepth 5 2>/dev/null); do
        echo -e "${YELLOW}Config:${NC} $cfg"
        if confirm "Delete this config?"; then
            rm -f "$cfg"
            echo -e "  ${GREEN}✓${NC} Deleted"
        fi
    done
fi

echo ""
echo -e "${GREEN}Reset complete.${NC}"
echo ""
echo "To start fresh:"
echo "  cd $REPO_DIR"
echo "  ./setup.sh"
echo "  ./run.sh --once"
echo ""
