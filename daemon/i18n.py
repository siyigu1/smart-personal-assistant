"""Centralized internationalization for the Python daemon.

All user-facing strings live here. Daemon code calls t(key, lang, **kwargs)
instead of inline if/else blocks.

Follows the same pattern as i18n/en.sh and i18n/zh.sh for the bash layer.
"""

_STRINGS = {
    "en": {
        # Acknowledgment
        "ack": "Got it \u2014 working on this now",

        # Onboarding welcome
        "welcome_onboarding": (
            "Hi {user_name}! I'm {assistant_name}. "
            "Let's set up your system \u2014 I'll ask a few questions about "
            "your schedule and projects. Takes about 15 minutes.\n\n"
            "Ready to get started? (just reply 'yes' or 'let\u2019s go')"
        ),

        # LLM error messages
        "error_auth": (
            "Claude CLI needs you to log in again. "
            "Go to your computer and run: claude login"
        ),
        "error_update": (
            "Claude CLI has an update available. "
            "Go to your computer and run: claude update"
        ),
        "error_prefix": "Action needed",
        "error_unknown_code": "Claude CLI error (exit code {code})",
        "error_llm_failure": (
            "\u26a0\ufe0f I tried to run *{operation}* but didn't get a response from the AI. "
            "This might be a temporary issue \u2014 I'll keep trying. "
            "If it persists, check `./status.sh errors` for details."
        ),

        # Cross-task notifications
        "cross_task_assigned": (
            "{from_name} assigned you: {description}\n"
            "Reply 'accept' or 'reject'"
        ),
    },
    "zh": {
        # Acknowledgment
        "ack": "\u6536\u5230 \u2014 \u6b63\u5728\u5904\u7406",

        # Onboarding welcome
        "welcome_onboarding": (
            "\u4f60\u597d {user_name}\uff01\u6211\u662f{assistant_name}\u3002"
            "\u8ba9\u6211\u4eec\u6765\u8bbe\u7f6e\u4f60\u7684\u7cfb\u7edf\u5427\u2014\u2014"
            "\u6211\u4f1a\u95ee\u51e0\u4e2a\u5173\u4e8e\u4f60\u7684\u65e5\u7a0b\u548c\u9879\u76ee\u7684\u95ee\u9898\uff0c"
            "\u5927\u6982 15 \u5206\u949f\u3002\n\n"
            "\u51c6\u5907\u597d\u4e86\u5417\uff1f\uff08\u56de\u590d'\u597d'\u6216'\u5f00\u59cb'\u5c31\u884c\uff09"
        ),

        # LLM error messages
        "error_auth": (
            "Claude CLI \u9700\u8981\u4f60\u91cd\u65b0\u767b\u5f55\u3002"
            "\u8bf7\u5230\u7535\u8111\u4e0a\u8fd0\u884c\uff1aclaude login"
        ),
        "error_update": (
            "Claude CLI \u6709\u66f4\u65b0\u3002"
            "\u8bf7\u5230\u7535\u8111\u4e0a\u8fd0\u884c\uff1aclaude update"
        ),
        "error_prefix": "\u9700\u8981\u4f60\u64cd\u4f5c",
        "error_unknown_code": "Claude CLI \u9519\u8bef\uff08\u9000\u51fa\u7801 {code}\uff09",
        "error_llm_failure": (
            "\u26a0\ufe0f \u5c1d\u8bd5\u8fd0\u884c *{operation}* "
            "\u4f46\u6ca1\u6709\u6536\u5230 AI \u7684\u56de\u590d\u3002"
            "\u53ef\u80fd\u662f\u4e34\u65f6\u95ee\u9898\u2014\u2014\u6211\u4f1a\u7ee7\u7eed\u5c1d\u8bd5\u3002"
            "\u5982\u679c\u6301\u7eed\u51fa\u73b0\uff0c\u8bf7\u8fd0\u884c `./status.sh errors` \u67e5\u770b\u8be6\u60c5\u3002"
        ),

        # Cross-task notifications
        "cross_task_assigned": (
            "{from_name} \u7ed9\u4f60\u5206\u914d\u4e86\u4efb\u52a1\uff1a{description}\n"
            "\u56de\u590d'\u63a5\u53d7'\u6216'\u62d2\u7edd'"
        ),
    },
}


def t(key: str, lang: str = "en", **kwargs) -> str:
    """Look up a translated string by key.

    Args:
        key: The string key (e.g. "ack", "welcome_onboarding").
        lang: Language code ("en" or "zh"). Falls back to "en".
        **kwargs: Format variables to interpolate into the string.

    Returns:
        The translated, formatted string.
    """
    strings = _STRINGS.get(lang, _STRINGS["en"])
    template = strings.get(key)
    if template is None:
        # Fall back to English
        template = _STRINGS["en"].get(key, key)
    if kwargs:
        return template.format(**kwargs)
    return template
