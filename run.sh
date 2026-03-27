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

if [[ "${1:-}" == "--help" || "${1:-}" == "-h" ]]; then
    echo "Usage: ./run.sh [config_path] [--once]"
    echo ""
    echo "  config_path   Path to .mc-config.json (optional)"
    echo "  --once        Run one cycle and exit (for testing)"
    echo ""
    echo "If no config path is given, searches:"
    echo "  1. MC_CONFIG environment variable"
    echo "  2. ~/Documents/Personal Assistant/.mc-config.json"
    exit 0
fi

# Check Python dependencies
missing=()
python3 -c "import slack_sdk" 2>/dev/null || missing+=("slack-sdk")
python3 -c "import dotenv" 2>/dev/null || missing+=("python-dotenv")
python3 -c "import schedule" 2>/dev/null || missing+=("schedule")

if [[ ${#missing[@]} -gt 0 ]]; then
    echo "Missing Python dependencies: ${missing[*]}"
    echo ""
    echo "Installing..."
    python3 -m pip install -r "$SCRIPT_DIR/daemon/requirements.txt" --quiet
    echo "Done."
    echo ""
fi

# Pass all args through to the daemon
exec python3 -m daemon.main "$@"
