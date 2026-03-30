#!/usr/bin/env bash
# Start the Personal Assistant daemon.
#
# Usage:
#   ./run.sh                    # Uses default config location
#   ./run.sh /path/to/.mc-config.json   # Specify config path
#   ./run.sh --once             # Run one cycle and exit (testing)

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$SCRIPT_DIR"

VENV_DIR="$SCRIPT_DIR/.venv"
LOG_DIR="$SCRIPT_DIR/logs"
mkdir -p "$LOG_DIR"
LOG_FILE="$LOG_DIR/daemon-$(date +%Y%m%d-%H%M%S).log"

# Detect language from config if available
LANG_CODE="en"
for candidate in \
    "${MC_CONFIG:-}" \
    "$HOME/Library/Mobile Documents/iCloud~md~obsidian/Documents/Personal Assistant/.mc-config.json" \
    "$HOME/Documents/Personal Assistant/.mc-config.json"; do
    if [[ -n "$candidate" && -f "$candidate" ]]; then
        LANG_CODE=$(python3 -c "import json; print(json.load(open('$candidate')).get('language','en'))" 2>/dev/null || echo "en")
        break
    fi
done

source "$SCRIPT_DIR/i18n/${LANG_CODE}.sh" 2>/dev/null || source "$SCRIPT_DIR/i18n/en.sh"

# Log everything to file
exec > >(tee -a "$LOG_FILE") 2>&1

echo "[$(date)] $MSG_RUN_STARTING"
echo "[$(date)] $MSG_RUN_LOG $LOG_FILE"

if [[ "${1:-}" == "--help" || "${1:-}" == "-h" ]]; then
    echo "Usage: ./run.sh [config_path] [--once]"
    echo ""
    echo "  config_path   Path to .mc-config.json"
    echo "  --once        Run one cycle and exit"
    exit 0
fi

# ─── Set up virtual environment if needed ───────────────────────

if [[ ! -d "$VENV_DIR" ]]; then
    echo "$MSG_RUN_CREATING_VENV"
    python3 -m venv "$VENV_DIR"
    echo "$MSG_RUN_INSTALLING"
    "$VENV_DIR/bin/pip" install -r "$SCRIPT_DIR/daemon/requirements.txt" --quiet
    echo ""
fi

# Use the venv's Python
PYTHON="$VENV_DIR/bin/python3"

# Check dependencies are installed in venv
missing=()
"$PYTHON" -c "import slack_sdk" 2>/dev/null || missing+=("slack-sdk")
"$PYTHON" -c "import dotenv" 2>/dev/null || missing+=("python-dotenv")
"$PYTHON" -c "import schedule" 2>/dev/null || missing+=("schedule")

if [[ ${#missing[@]} -gt 0 ]]; then
    echo "$MSG_RUN_INSTALLING_MISSING ${missing[*]}"
    "$VENV_DIR/bin/pip" install -r "$SCRIPT_DIR/daemon/requirements.txt" --quiet
    echo ""
fi

# Pass all args through to the daemon
exec "$PYTHON" -m daemon.main "$@"
