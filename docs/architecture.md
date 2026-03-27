# Architecture

## Overview

Mission Control uses a hybrid architecture: a lightweight Python daemon handles all deterministic work (polling, reminders, scheduling) with zero LLM tokens, and invokes the AI only when intelligence is needed (responding to messages, composing dispatches, classifying tasks).

```
┌─────────────────────────────────────────────────────────────┐
│  Daemon (Python, always running)                             │
│                                                              │
│  Polling ─── New message? ──→ Yes ──→ Invoke LLM             │
│              No? → sleep                                     │
│                                                              │
│  Reminders ── Due? ──→ Post to Slack (zero tokens)           │
│                                                              │
│  Scheduler ── 8am? ──→ Invoke LLM for morning dispatch       │
│               7pm? ──→ Invoke LLM for EOD summary            │
└───────────────┬────────────────────────┬────────────────────┘
                │                        │
          Slack SDK                 claude -p (CLI)
          (direct API)             (subscription)
                │                        │
          ┌─────▼─────┐          ┌───────▼──────┐
          │   Slack    │          │    Claude     │
          └───────────┘          └──────────────┘
```

## Why Hybrid?

| Approach | Daily Tokens | Speed | Reliability |
|---|---|---|---|
| All-LLM (every 5 min) | ~60-80K | Slow (session spin-up) | Depends on LLM availability |
| Hybrid (code + LLM on demand) | ~10-20K | Instant for deterministic work | Code never fails for polling |

## Zero-Permission Design

The LLM never touches files or APIs directly. The daemon:
1. Reads state files (Python)
2. Builds a complete prompt with all context inline
3. Sends to LLM as pure text
4. Parses the text response
5. Posts to Slack and applies file updates (Python)

No tool permissions, no MCP, no API keys for side services.

## Pluggable Design

Both LLM providers and chat channels are pluggable:

- **LLM**: `daemon/llm/base.py` defines the interface. `claude_cli.py` is the first implementation.
- **Channels**: `daemon/channels/base.py` defines the interface. `slack.py` is the first implementation.

Adding a new LLM or channel means implementing one class with 2-3 methods.

## Comparison with OpenClaw

Mission Control shares the same architectural insight as OpenClaw (335K+ stars):

| Layer | Mission Control | OpenClaw |
|---|---|---|
| Deterministic daemon | Python, ~800 LOC | TypeScript Gateway, ~50K LOC |
| LLM invocation | `claude -p` (subscription) | Pi agent (API keys) |
| Channels | Slack (pluggable) | 20+ channels |
| State | Markdown files | Sessions + DB |
| Scale | Personal/family | Multi-user platform |

Same pattern, radically different scale. Mission Control is the "personal-scale OpenClaw."
