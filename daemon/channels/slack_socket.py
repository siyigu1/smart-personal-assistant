"""Slack Socket Mode handler for instant message processing.

Uses slack-bolt to connect via Socket Mode (WebSocket), which provides
instant event delivery without polling. Requires an App-Level Token
(xapp-...) in addition to the Bot User OAuth Token (xoxb-...).

Socket Mode must be enabled in the Slack App settings.
"""

from typing import Callable, Tuple


def create_socket_app(
    bot_token: str,
    app_token: str,
    on_message: Callable[[str, str, Callable], None],
) -> Tuple:
    """Create a Slack Bolt app with Socket Mode handler.

    Args:
        bot_token: Bot User OAuth Token (xoxb-...)
        app_token: App-Level Token (xapp-...) for Socket Mode
        on_message: Callback(channel_id, text, say_fn) for incoming messages

    Returns:
        Tuple of (app, handler) — call handler.start_async() to run.

    Raises:
        ImportError: If slack-bolt is not installed
        Exception: If Socket Mode connection fails
    """
    from slack_bolt.async_app import AsyncApp
    from slack_bolt.adapter.socket_mode.async_handler import AsyncSocketModeHandler

    app = AsyncApp(token=bot_token)

    @app.event("message")
    async def handle_message_event(event, say):
        """Handle incoming message events from Slack."""
        # Skip bot messages
        if event.get("bot_id") or event.get("subtype"):
            return

        text = event.get("text", "").strip()
        if not text:
            return

        channel_id = event.get("channel", "")

        # Call the daemon's message handler
        # The say function lets us post replies
        def say_fn(msg):
            import asyncio
            loop = asyncio.get_event_loop()
            if loop.is_running():
                asyncio.ensure_future(say(msg))
            else:
                loop.run_until_complete(say(msg))

        # Run synchronously since the daemon's run_operation is sync
        on_message(channel_id, text, lambda msg: say_fn(msg))

    handler = AsyncSocketModeHandler(app, app_token)
    print("[socket] Socket Mode handler created")

    return app, handler
