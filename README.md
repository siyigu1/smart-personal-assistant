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

## Quick Start — Use with Any AI (no install needed)

1. Download the `framework/` folder from this repo
2. Open your favorite AI (ChatGPT, Claude, Gemini, etc.)
3. Upload the folder or paste the contents of `START HERE.md`
4. Say: **"Read all the files in this folder and help me manage my life"**
5. The AI interviews you about your schedule and projects (~15 min)
6. You're set up. Share the folder at the start of each session.

**Prompt to paste:**
```
I'm using a personal life management framework. The instructions
are in the attached file "START HERE.md". Please read it and all
other .md files in the folder, then help me manage my day.
```

> Note: without a scheduler, the AI can't proactively reach out at scheduled times. It works as a responsive assistant — you come to it. For proactive features (morning dispatch, auto check-ins, reminders), use the daemon below.

## Quick Start — Automated Slack Bot (proactive features)

```bash
git clone https://github.com/siyigu1/smart-personal-assistant.git
cd smart-personal-assistant
./setup.sh
./run.sh
```

The setup wizard asks for: mode, language, LLM provider, Slack channel, your name. That's it — the AI handles the rest conversationally on first run.

### After Setup

If you chose **background service**, the daemon is already running — the AI will reach out in Slack to onboard you.

If you chose **manual**, start with:
```bash
./run.sh
```

Other options:
```bash
./run.sh --once                        # Run one cycle and exit (testing)
./run.sh /path/to/.mc-config.json      # Use a specific config file
```

To stop a background service:
```bash
# macOS
launchctl stop com.mission-control.daemon
# Linux
systemctl --user stop mission-control
```

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

一套用 markdown 文件构成的 AI 生活管理框架。核心是方法论文档——给任何 AI 都能用。

## 最简单的用法（不需要安装任何东西）

1. 下载 `framework/` 文件夹
2. 打开你常用的 AI（ChatGPT、Claude、豆包、Gemini…）
3. 上传文件夹，或粘贴 `START HERE.md` 的内容
4. 说：**"读一下这个文件夹里的所有文件，帮我管理生活"**
5. AI 会用对话方式了解你的日程和项目（约15分钟）
6. 搞定。以后每次开聊天时分享这个文件夹就行。

## 自动化版本（Slack 机器人）

```bash
git clone https://github.com/siyigu1/smart-personal-assistant.git
cd smart-personal-assistant
./setup.sh    # 设置时选"2. 中文"
./run.sh
```

### 设置完成后

如果选了**后台服务**，守护进程已经在运行了——去 Slack 频道看看欢迎消息。

手动启动：
```bash
./run.sh
```

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
