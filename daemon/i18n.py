"""Centralized internationalization for the Python daemon.

Loads translations from i18n/en.json, i18n/zh.json, etc.
Daemon code calls t(key, lang, **kwargs) for all user-facing strings.
"""

import json
import os

_STRINGS = {}
_I18N_DIR = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "i18n")


def _load_languages():
    """Load all .json language files from the i18n directory."""
    global _STRINGS
    if not os.path.isdir(_I18N_DIR):
        return
    for f in os.listdir(_I18N_DIR):
        if f.endswith(".json"):
            lang = f[:-5]
            path = os.path.join(_I18N_DIR, f)
            try:
                with open(path, encoding="utf-8") as fh:
                    _STRINGS[lang] = json.load(fh)
            except (json.JSONDecodeError, OSError):
                pass


_load_languages()


def t(key: str, lang: str = "en", **kwargs) -> str:
    """Look up a translated string by key."""
    strings = _STRINGS.get(lang, _STRINGS.get("en", {}))
    template = strings.get(key)
    if template is None:
        template = _STRINGS.get("en", {}).get(key, key)
    if kwargs:
        return template.format(**kwargs)
    return template
