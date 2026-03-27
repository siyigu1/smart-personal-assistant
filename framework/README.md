# Smart Personal Assistant — Framework

This folder contains a framework for managing your life with the help of an AI assistant. It's a set of markdown files that define how to organize work, prioritize tasks, manage your schedule, and track progress across multiple projects.

**You don't need any special software to use this.** Give these files to any AI — ChatGPT, Claude, Gemini, a local model — and ask it to help you manage your day. The AI reads these files, understands your situation, and helps you stay on track.

## How to Use

### Option A: Just talk to an AI (simplest)
1. Open your favorite AI assistant (ChatGPT, Claude, etc.)
2. Upload or paste the contents of `Getting Started.md`
3. The AI will interview you about your life, schedule, and projects
4. It fills in the framework files based on your answers
5. From then on, share the files with your AI whenever you need help planning

### Option B: Use with our daemon (automated)
1. Run `./setup.sh` in the repo to configure Slack integration
2. Run `./run.sh` to start the daemon
3. The AI reaches out to you in Slack and runs the onboarding interview
4. After that, it checks in daily with dispatches, reminders, and summaries

### Option C: Use with any other agent system
These files work with OpenClaw, Claude Cowork, or any system that can read markdown and talk to you via a chat channel. See `docs/alternatives.md` in the repo.

## The Files

| File | What it does | Fill in when? |
|------|-------------|---------------|
| **Getting Started.md** | Guide for your AI to interview you and set up everything | First session — give this to any AI |
| **Cognitive Levels.md** | L1/L2/L3 system for classifying how much of YOUR attention a task needs | Pre-filled — just read and understand |
| **Priority Framework.md** | Eisenhower Matrix (importance × urgency) for classifying new items | Pre-filled — just read and understand |
| **Daily Scaffolding.md** | Your daily schedule template — time blocks, commitments, capacity | Filled during onboarding interview |
| **Workstreams.md** | Your active projects with priorities, tasks, and context | Filled during onboarding interview |
| **Weekly Goals.md** | This week's objectives per project | Filled during first weekly planning |
| **Cowork Agent Playbook.md** | Templates for daily dispatches, check-ins, summaries | Pre-filled — the AI follows these |

## The Core Ideas

### 1. Cognitive Levels
Not all tasks need the same amount of your brain. We classify by how much of YOUR attention is needed:
- **L1** — Deep focus (design, debug, brainstorm). You can't do anything else.
- **L2** — Light supervision (AI works, you review). One at a time.
- **L3** — Autonomous (AI handles it, you just wait). Unlimited parallel.

**Key rule:** Never two L2s at once. One L2 + any number of L3s.

### 2. Eisenhower Matrix
Every new item gets classified by importance × urgency:
- **Q1** (Important + Urgent) → Do now
- **Q2** (Important + Not Urgent) → Protect time for this — it's where the best work lives
- **Q3** (Not Important + Urgent) → Delegate or quick-fix
- **Q4** (Not Important + Not Urgent) → Drop it

### 3. Workstream Management
Your life has multiple "workstreams" (projects, responsibilities). Each has:
- A priority ranking (so the AI suggests the right thing at the right time)
- A "pick-up packet" (context for switching back to it quickly)
- Pending tasks with cognitive levels
- A decisions log (so you don't forget why you chose something)

### 4. Daily Scaffolding
Your day has a rhythm — fixed commitments, deep work windows, low-energy times. The AI learns your rhythm and suggests the right task for the right moment. Not a rigid schedule — a flexible scaffold that adapts when things change.

### 5. Weekly Cycles
- **Sunday:** Plan the week — set goals per workstream
- **Daily:** Morning dispatch → check-ins → EOD summary
- **Friday:** Weekly reflection — what worked, what didn't, what to change
