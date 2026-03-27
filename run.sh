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

# Pass all args through to the daemon
exec python3 -m daemon.main "$@"
