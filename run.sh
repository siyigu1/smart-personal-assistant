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

if [[ "${1:-}" == "--help" || "${1:-}" == "-h" ]]; then
    echo "Usage: ./run.sh [config_path] [--once]"
    echo ""
    echo "  config_path   Path to .mc-config.json (optional)"
    echo "  --once        Run one cycle and exit (for testing)"
    echo ""
    echo "If no config path is given, searches:"
    echo "  1. MC_CONFIG environment variable"
    echo "  2. ~/Documents/Personal Assistant/.mc-config.json"
    echo "  3. iCloud, Dropbox, Google Drive, OneDrive locations"
    exit 0
fi

# ─── Set up virtual environment if needed ───────────────────────

if [[ ! -d "$VENV_DIR" ]]; then
    echo "Creating virtual environment..."
    python3 -m venv "$VENV_DIR"
    echo "Installing dependencies..."
    "$VENV_DIR/bin/pip" install -r "$SCRIPT_DIR/daemon/requirements.txt" --quiet
    echo "Done."
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
    echo "Installing missing dependencies: ${missing[*]}"
    "$VENV_DIR/bin/pip" install -r "$SCRIPT_DIR/daemon/requirements.txt" --quiet
    echo "Done."
    echo ""
fi

# Pass all args through to the daemon
exec "$PYTHON" -m daemon.main "$@"
