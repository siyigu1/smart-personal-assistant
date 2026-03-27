# Smart Personal Assistant

An AI-powered personal life management system. Your own AI agent that lives in Slack — managing your schedule, tracking tasks, sending reminders, and adapting to your daily rhythm.

**Three ways to set up:**
- `./setup.sh` — Interactive script (daemon or cowork mode)
- `./setup.sh --mode cowork` — All-Claude mode (no Python daemon)
- Load `skills/setup/SKILL.md` in Claude — Conversational setup

---

## How It Works

A lightweight Python daemon runs in the background. It handles polling, reminders, and scheduling with **zero AI tokens**. The AI is only called when intelligence is actually needed (~15 invocations/day).

```
┌──────────────────────────────────────────────────────────┐
│  Daemon (Python, always running)                          │
│                                                           │
│  Slack Poll ── new message? ─── No → sleep (zero tokens)  │
│                                  Yes → invoke AI           │
│                                                           │
│  Reminders ── due? ──→ post to Slack (zero tokens)        │
│                                                           │
│  Scheduler ── 8am → AI: "compose morning dispatch"        │
│               7pm → AI: "compose EOD summary"             │
└───────────────┬──────────────────┬───────────────────────┘
          Slack SDK           claude -p (CLI)
          (direct API)        (uses subscription)
```

**Token usage:** ~15-20K/day (vs ~60-80K for all-LLM approach). Both included in $20/mo Claude Pro.

## Features

- **Morning dispatch** — Daily priorities posted to Slack
- **Smart check-ins** — Midday/afternoon status checks
- **EOD summary** — What got done, weekly progress
- **Slack listener** — "What should I work on?", "Remind me in 2 hours..."
- **Reminder system** — Natural language, auto-fires
- **Workstream management** — Multiple projects with priorities and cognitive levels (L1-L3)
- **Eisenhower Matrix** — Auto-classify new items by importance x urgency
- **Weekly planning** — Sunday goal-setting, Friday reviews
- **Grocery list** — "Add milk" → auto-categorized by store
- **Travel packing** — Master template, scales by trip length/weather
- **Family extension** — Second user with cross-task delegation
- **Bilingual** — Full English and Chinese support

## Quick Start

```bash
git clone https://github.com/siyi-gu/smart-personal-assistant.git
cd smart-personal-assistant
./setup.sh
```

The wizard walks you through:
1. System check (Python, Claude CLI)
2. Setup mode (daemon vs cowork)
3. Language (English / 中文)
4. LLM provider (Claude CLI using subscription)
5. Slack App creation (step-by-step with auto-opening URLs)
6. Your schedule, workstreams, and features
7. Dependency installation + daemon startup

## Architecture

```
smart-personal-assistant/
├── setup.sh                    # Interactive installer
├── daemon/                     # Hybrid daemon (Python)
│   ├── channels/               # Pluggable chat channels
│   │   ├── base.py             #   Abstract interface
│   │   └── slack.py            #   Slack SDK
│   ├── llm/                    # Pluggable LLM providers
│   │   ├── base.py             #   Abstract interface
│   │   └── claude_cli.py       #   claude -p (subscription)
│   ├── main.py                 # Entry point + main loop
│   ├── scheduler.py            # Cron-like scheduling
│   ├── reminder_engine.py      # Reminder check/fire (zero tokens)
│   ├── context_builder.py      # Build prompts from state files
│   └── ...
├── templates/                  # Agent-agnostic templates
│   ├── core/{en,zh}/           #   State file templates
│   └── prompts/{en,zh}/        #   System prompt + playbook
├── cowork/                     # Claude Desktop scheduled tasks
├── skills/setup/SKILL.md       # Conversational setup skill
└── docs/
```

### Zero-Permission Design

The AI never accesses files or APIs directly. The daemon:
1. Reads state files → builds prompt with context inline
2. Sends pure text to AI → receives pure text back
3. Parses response → posts to Slack, updates files

No tool permissions, no MCP, no API keys for side services.

### Pluggable

Add new LLM providers or chat channels by implementing one class:

```python
# daemon/llm/your_provider.py
class YourLLM(LLMBridge):
    def invoke(self, prompt: str) -> str:
        # Send prompt, return response text
        ...
```

| LLM | Status | Mechanism |
|-----|--------|-----------|
| Claude | v1 | `claude -p` (subscription) |
| Ollama | Future | Local HTTP API |
| OpenAI | Future | API |

| Channel | Status | Library |
|---------|--------|---------|
| Slack | v1 | `slack-sdk` |
| Discord | Future | `discord.py` |
| Telegram | Future | `python-telegram-bot` |

## Alternative Setup Paths

### OpenClaw
If you run [OpenClaw](https://github.com/openclaw/openclaw), you can use our state files and system prompt directly. See [docs/alternatives.md](docs/alternatives.md).

### Claude Desktop (No Daemon)
```bash
./setup.sh --mode cowork
```
Everything runs through Claude Desktop scheduled tasks. Simpler but uses ~4x more tokens.

### Conversational Setup
Load `skills/setup/SKILL.md` in any Claude session for guided setup without running a script.

## Token Costs

All included in Claude Pro subscription ($20/mo):

| Setup | Daily Tokens | Description |
|-------|-------------|-------------|
| Minimal | ~5K | Listener only |
| Standard | ~15-20K | Daemon mode, all features |
| Cowork mode | ~60-80K | All-Claude, no daemon |

## Cognitive Levels

| Level | Name | Parallelize? |
|-------|------|-------------|
| L1 | Deep Involvement (design, debug) | No |
| L1.5 | Scoping (specs, task breakdown) | No |
| L2 | Light Involvement (agent works, you review) | One at a time |
| L3 | Autonomous (agent handles it) | Unlimited |

**Key rule:** Never two L2 tasks in parallel. One L2 + any number of L3s.

## Contributing

PRs welcome! Areas that could use help:
- **New LLM providers** — Ollama, OpenAI, Gemini
- **New channels** — Discord, Telegram, WeChat
- **Localization** — More languages
- **Feature templates** — Fitness, meal planning, budgeting

## License

MIT

---

# 中文说明

## 这是什么？

一个用 AI + Slack + Obsidian 搭建的个人生活管理系统。

你的 AI 助手住在 Slack 里，帮你管理日程、追踪多个项目、发提醒、做周总结——完全按照你的节奏定制。

## 快速开始

```bash
git clone https://github.com/siyi-gu/smart-personal-assistant.git
cd smart-personal-assistant
./setup.sh
```

设置时选"2. 中文"，agent 就会用中文跟你沟通。

## 混合架构

一个轻量 Python 守护进程处理所有确定性工作（轮询、提醒、定时），**零 AI 消耗**。只有需要智能时才调用 AI（每天约15次）。

Token 用量：~15-20K/天（全包在 Claude Pro $20/月订阅里）。

## 功能

- 早间 Dispatch、午间/下午签到、日终总结
- Slack 监听器 — 随时发消息
- 提醒系统 — 自然语言设置
- 工作流管理 — 多项目、优先级、认知层级
- 艾森豪威尔矩阵 — 新事项自动分类
- 周计划 — 周日目标设定 + 周五回顾
- 购物清单、旅行打包清单
- 家庭扩展 — 给家人也搭一套
