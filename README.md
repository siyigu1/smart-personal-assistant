# Smart Personal Assistant

[中文说明](README.zh.md)

A framework for managing your life with AI. Give these markdown files to any AI — ChatGPT, Claude, Gemini, a local model — and it becomes your personal life management assistant.

The framework is the product. The daemon is optional infrastructure.

---

## Overview

Smart Personal Assistant is a set of markdown files that teach any AI how to help you manage multiple projects, track tasks, plan your day, and stay organized. It works in two modes:

1. **Framework-only** — Give the files to any AI and chat. No code, no setup.
2. **Daemon mode** — A lightweight Python script adds proactive features: morning dispatches, scheduled check-ins, reminders, and instant Slack responses.

---

## The Framework

The framework is a collection of markdown files that define how to organize work, prioritize tasks, and manage your schedule. Any AI that reads these files can serve as your assistant.

### Core Files

| File | Purpose |
|------|---------|
| `START HERE.md` | Entry point — tells the AI what to do and how to behave |
| `Cognitive Levels.md` | L1/L2/L3 system — classify tasks by how much of YOUR attention they need |
| `Priority Framework.md` | Eisenhower Matrix — auto-classify by importance × urgency |
| `Cowork Agent Playbook.md` | Templates for daily dispatches, check-ins, and summaries |
| `Getting Started.md` | Onboarding guide — the AI interviews you to set up the system |

### User Files (created during onboarding)

| File | Purpose |
|------|---------|
| `Workstreams.md` | Your projects, tasks, priorities, and context |
| `Weekly Goals.md` | This week's objectives per project |
| `Daily Scaffolding.md` | Your schedule mapped by capacity — when to suggest what |
| `Preferences.md` | Long-term memory — your rules for how the bot behaves |
| `Automations.md` | Scheduled events and reminders (human-readable view) |

### Key Concepts

**Cognitive Levels** — Not all tasks need the same brain power:
- **L1** — Deep focus (design, debug). Can't do anything else.
- **L2** — Light supervision (AI works, you review). One at a time.
- **L3** — Autonomous (AI handles it). Unlimited parallel.
- **Rule:** Never two L2s at once.

**Eisenhower Matrix** — Every new item gets classified:
- Q1 (Important + Urgent) → Do now
- Q2 (Important + Not Urgent) → Protect time for this
- Q3 (Not Important + Urgent) → Delegate or quick-fix
- Q4 (Not Important + Not Urgent) → Drop it

**Daily Scaffolding** — Your day mapped by capacity. The AI suggests the right task at the right time.

**Weekly Cycles** — Sunday plan → daily dispatches → Friday reflection.

---

## Plugins

Plugins extend the assistant with domain-specific features. Each plugin is a folder with a `playbook.md` that teaches the AI a new capability.

### Built-in Plugins

| Plugin | What it does |
|--------|-------------|
| **grocery** | Shopping list organized by store type (Costco, regular, Chinese grocery). Auto-categorizes items. |
| **travel** | Trip packing with scaling rules. Generates packing lists based on trip length, weather, and travel party. |

### How Plugins Work

1. Tell the bot: "install the grocery plugin"
2. The bot reads the plugin's playbook and adds routing rules to your `Preferences.md`
3. Future requests matching those triggers ("add milk to grocery list") route to the plugin automatically
4. Plugin data lives in your notes folder: `plugins/grocery/my_grocery.md`

### Creating Your Own Plugin

Create a folder at `plugins/my_plugin/` with a `playbook.md`:
```markdown
# My Plugin

## Installation
When installed, add to Preferences.md:
- my_plugin: [description]. Triggers: [phrases]. Data: plugins/my_plugin/[files].

## How the Assistant Should Behave
[Rules for the AI]

## User Data Files
[What files to create and maintain]
```

Plugins are available in English (`plugins/en/`) and Chinese (`plugins/zh/`).

---

## The Daemon

The daemon is a lightweight Python script that adds proactive features the framework alone can't provide: scheduled dispatches, instant message handling, and automated reminders.

### How It Receives Messages

**Slack Socket Mode** (preferred) — Instant event-driven message handling. No polling delay. When you send a Slack message, the daemon processes it immediately.

**Polling** (fallback) — Checks for new messages every 60 seconds. Used when Socket Mode isn't available.

### How It Uses the AI

The daemon invokes `claude -p` (Claude CLI) only when intelligence is needed. It passes the prompt via stdin and receives pure text back. Each call is independent — no sessions, no state.

**Token usage:** ~15-20K/day with all features enabled. Included in Claude Pro ($20/mo).

### Zero-Permission Design

The AI never accesses files or APIs directly. The daemon handles all I/O:

```
Daemon reads files → builds prompt → sends to AI via stdin
AI returns JSON text → daemon parses → posts to Slack + writes files
```

No tool permissions, no MCP, no file system access. The AI is pure text-in, text-out. This makes it portable to any LLM provider.

---

## Getting Started

### Method 1: Framework Only (any AI, no install)

Use this if you just want the methodology — works with ChatGPT, Claude, Gemini, or any AI.

**Step 1: Download the framework**
```bash
git clone https://github.com/siyigu1/smart-personal-assistant.git
```
Copy the `framework/en/` folder (or `framework/zh/` for Chinese) somewhere convenient.

**Step 2: Share with your AI**

Open your favorite AI and paste this prompt:
```
I'm using a personal life management framework. Please read the attached
files starting with "START HERE.md", then help me manage my day.
```

Upload all the `.md` files from the framework folder.

**Step 3: Onboarding**

The AI will interview you about your schedule, projects, and preferences (~15 minutes). It creates your personal files: Workstreams.md, Daily Scaffolding.md, Weekly Goals.md, and Preferences.md.

**Step 4: Daily use**

Share your files at the start of each session. Ask things like:
- "What should I work on?"
- "Add milk to grocery list" (if grocery plugin installed)
- "Classify this new task"
- "Run my morning dispatch"

To install plugins, also share the plugin's `playbook.md` and say "install this plugin."

> Without a scheduler, the AI can only respond when you message it. For proactive features (morning dispatches, automatic reminders), use the daemon.

---

### Method 2: Daemon Mode (proactive features)

Use this for the full experience — scheduled dispatches, instant Slack responses, automated reminders.

**Prerequisites:**
- Python 3.10+
- Claude CLI (`claude`) with Pro/Max subscription
- A Slack workspace

**Step 1: Clone and run setup**
```bash
git clone https://github.com/siyigu1/smart-personal-assistant.git
cd smart-personal-assistant
./setup.sh
```

The setup wizard walks you through:
1. Language (English / 中文)
2. Your name and assistant name
3. LLM provider (Claude CLI)
4. Slack App creation (with pre-filled manifest)
5. Notes folder location (iCloud, Dropbox, local, etc.)
6. Family extension (optional second user)

**Step 2: Start the daemon**
```bash
./run.sh
```

The daemon starts and connects to Slack. On first run, the AI reaches out to onboard you — the same 15-minute interview, but in Slack.

**Step 3: Onboarding**

The AI messages you in Slack to learn about your schedule and projects. Answer conversationally. It creates all your files and sets up automations (morning dispatch, check-ins, etc.).

**After setup:**
```bash
./status.sh              # Check daemon status + recent activity
./status.sh activity     # Recent activity log
./status.sh llm          # Recent AI calls
./status.sh errors       # Recent errors
./run.sh --once          # Test one cycle
```

---

## How to Use

### Morning Dispatch

Every morning at your configured time, the AI posts your daily priorities:
```
Good morning! Here's your dispatch for Monday, April 1:

FIXED TODAY:
- 11:00am Team meeting
- 4:30pm Kid pickup

PRIORITY TASKS:
1. Finish design mockup — ProjectA — L1 — 10:00-12:00
2. Review PR #42 — ProjectB — L2 — 1:00-2:00

AGENTS CAN RUN WITHOUT YOU (L3):
- Deploy staging build

Any changes to today?
```

### End of Day Summary

Every evening, the AI reviews your day:
```
EOD Summary — Monday, April 1

COMPLETED:
- [x] Design mockup — ProjectA
- [x] Review PR #42 — ProjectB

ROLLED TO TOMORROW:
- [ ] Write tests — blocked on staging

WEEKLY PROGRESS:
- ProjectA: 3/5 goals done — on track
- ProjectB: 1/3 goals done — at risk

WINS:
- Design mockup done ahead of schedule!
```

### End of Week Review

Every Friday, the AI reflects on patterns:
```
WEEKLY REFLECTION:
- Deep work hours: ~18h (target: 20h)
- Context switches per day: ~4 (good)
- What worked: Morning dispatch → deep work flow
- What didn't: Wednesday lost to unplanned meetings
- Next week: Protect Wednesday morning block
```

### File Tidying

Every 7 days (or on demand), the AI cleans up your files:
- Moves completed tasks to quarterly archive (`archive/2026-Q2.md`)
- Cleans up workstream pending items
- Reorganizes and deduplicates
- Updates Weekly Goals to reflect current state

Trigger manually: "tidy up my files"

### Grocery List (plugin)

```
You: "add milk and eggs"
Bot: "Added milk to Regular Grocery, eggs to Regular Grocery."

You: "planning a costco trip"
Bot: "Here's your Costco list:
  • Paper towels
  • Trash bags
  • Sparkling water (bulk)
  Also available at Costco: eggs"
```

### Reminders

```
You: "remind me tomorrow at 3pm to call the doctor"
Bot: "Got it — I'll remind you tomorrow at 3pm."

(Next day at 3pm)
Bot: "Reminder: call the doctor"
```

Reminders are automations — they use the same system as scheduled dispatches.

---

## System Deep Dive

### Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                  FRAMEWORK (standalone, any AI)               │
│                                                              │
│  User's notes folder (Obsidian/iCloud/Dropbox):             │
│  ├── reference/          baseline methodology files          │
│  ├── Workstreams.md      user's projects and tasks           │
│  ├── Preferences.md      long-term memory (bot rules)        │
│  ├── Automations.md      human-readable schedule view        │
│  └── plugins/            plugin data files                   │
│                                                              │
│  Plugins (in repo):                                          │
│  └── plugins/{en,zh}/    plugin playbooks by language         │
└──────────────────────────────┬───────────────────────────────┘
                               │
                    (optional)  │ daemon reads/writes
                               ▼
┌─────────────────────────────────────────────────────────────┐
│                    DAEMON (deterministic)                     │
│                                                              │
│  Event Loop:                                                │
│    Socket Mode ── message → instant handler → invoke AI      │
│    Timer ── every 60s:                                       │
│      1. Check automations.json → fire due events            │
│      2. Check cross-tasks → notify family members           │
│      3. Run maintenance (1am-4am only)                      │
│                                                              │
│  data/{user}/ ── daemon internals (not in Obsidian):        │
│    automations.json, short-term-memory.json,                │
│    conversation-state.json, cache/                           │
└──────────────────────────────┬───────────────────────────────┘
                               │
                     invoke AI  │ only when intelligence needed
                               ▼
┌─────────────────────────────────────────────────────────────┐
│                    ERROR TOLERANCE LAYER                      │
│                                                              │
│  Input:  strip noise from files, attach only needed context  │
│  Output: extract JSON via brace-counting, fallback to text   │
│  Errors: auth → notify once, timeout → retry next cycle      │
└──────────────────────────────┬───────────────────────────────┘
                               │
                               ▼
┌─────────────────────────────────────────────────────────────┐
│                    AI (text-in, text-out)                     │
│                                                              │
│  Returns JSON:                                               │
│  { messages, files, add_automations, short_term_memory,     │
│    need_more_context, trigger_tidy, onboarding_complete }   │
└─────────────────────────────────────────────────────────────┘
```

### Memory System

| Layer | Location | TTL | Purpose |
|-------|----------|-----|---------|
| **Conversation** | `data/{user}/conversation-state.json` | 2 hours | Multi-turn chat log (onboarding, planning) |
| **Short-term** | `data/{user}/short-term-memory.json` | 7 days | Cross-message context. Auto-fades. |
| **Long-term** | `Preferences.md` (in Obsidian) | Permanent | User rules, bot behavior. Survives any platform. |

Every 7 days, the daemon consolidates: important short-term items move to Preferences.md, stale entries are pruned.

### Automated Maintenance (1am-4am)

| Task | Frequency | AI? |
|------|-----------|-----|
| Memory consolidation | 7 days | Yes — reviews STM, moves to Preferences |
| Context tidying | 7 days | Yes — archives completed tasks, cleans files |
| OS update check | Daily | No — `softwareupdate -l`, writes to System Notices |
| AI CLI update check | Daily | No — `claude update --check`, writes to System Notices |

Results appear in System Notices.md → the AI includes them in your morning dispatch.

### Smart Context Loading

Not every AI call needs every file. The daemon sends only what's needed:

| Operation | Files sent |
|-----------|-----------|
| Morning dispatch | Workstreams, Weekly Goals, Daily Scaffolding, System Notices |
| Check-in | Weekly Goals |
| EOD summary | Weekly Goals, Workstreams |
| User message | Workstreams, Weekly Goals, Daily Scaffolding |
| Always attached | Preferences.md |

If the AI needs more, it returns `need_more_context: ["Cognitive Levels"]` and the daemon does a second call with those files added.

### Multi-User Support

The daemon supports multiple users (family). Each user has:
- Their own Slack channel
- Their own notes folder
- Their own daemon data (memory, automations, conversation)
- Independent onboarding

Cross-task delegation: "add 倒垃圾 to Hao's list" → Hao's bot notifies him → when done, you get notified.

### Pluggable Architecture

| Component | How to extend |
|-----------|--------------|
| LLM provider | Implement `LLMBridge` in `daemon/llm/` |
| Chat channel | Implement `ChannelClient` in `daemon/channels/` |
| Feature | Create a plugin in `plugins/` |
| Language | Add `i18n/xx.sh` + `i18n/xx.json` + `framework/xx/` + `plugins/xx/` |

---

## Contributing

PRs welcome! Areas that could use help:
- **New plugins** — fitness tracking, meal planning, budgeting, habit tracking
- **New LLM providers** — Ollama, OpenAI, Gemini
- **New channels** — Discord, Telegram, WeChat
- **Localization** — More languages beyond EN/ZH

## License

MIT

---
