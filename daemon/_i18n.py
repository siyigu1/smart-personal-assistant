"""Thin wrapper to import from the i18n package."""
import sys
import os
sys.path.insert(0, os.path.join(os.path.dirname(__file__), ".."))
from i18n.daemon_strings import t  # noqa: E402, F401
