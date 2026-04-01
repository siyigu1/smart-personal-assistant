# Migration Prompt — Port Existing Files to Smart Personal Assistant

> Give this file to Claude (or any AI) along with your existing Mission Control / life management files. It will read your files and generate the new framework-compatible versions.

---

## Instructions for the AI

I'm migrating my existing personal management files to the Smart Personal Assistant framework. I'll share my current files with you. Please:

1. **Read all my existing files** — understand my workstreams, schedule, goals, preferences, and any automations/reminders I have.

2. **Generate these files** in the new framework format. Write each one as a complete file I can save directly:

### Files to generate:

**Workstreams.md** — Convert my existing projects/workstreams. For each one, include:
```
## N. [Name]
- **Phase:** [planning/active/maintenance]
- **Cognitive Level:** [L1/L2/L3 mix]
- **Status:** [current status]
- **Next Milestone:** [what I'm working toward]
- **Milestone Date:** [if I have one]
- **Pick-Up Packet:**
  - [Context for resuming this workstream — pull from my existing notes]
- **Decisions Log:**
  - [Any decisions I've recorded]

### Pending Tasks
[My existing tasks, with cognitive levels]

### Completed
[Any completed items I've recorded]
```
Preserve my priority order. Keep all my existing task details.

**Daily Scaffolding.md** — Convert my schedule:
```
## Weekday

| Time | Block | Capacity |
|------|-------|----------|
| ... | ... | L1/L2/L3/— |

## Fixed Commitments
[My meetings, pickups, etc.]

## Deep Work Blocks
[My best focus times]

## Off-Limits Times
[Times I don't want notifications]
```

**Weekly Goals.md** — Convert my current week's goals:
```
## [Current Week]

### [Workstream Name]
**P1 — Must Do:**
- [ ] [task]

**P2 — Should Do:**
- [ ] [task]
```

**Preferences.md** — Extract any preferences I've stated about how I work:
```
## Communication Style
[How I like the bot to talk to me]

## Notification Rules
[When/how to notify me]

## Other
[Any other rules]
```

**Automations** — Convert my existing scheduled tasks/reminders into this JSON format. Return as a JSON code block I can save as automations.json:
```json
[
  {
    "time": "HH:MM",
    "when": {"days": ["mon","tue",...]} or {"dates": ["MM-DD"]} or {"dates": ["YYYY-MM-DD"]},
    "action": "llm" or "message",
    "name": "descriptive name",
    "prompt": "..." (for llm actions) or "text": "..." (for message actions)
  }
]
```

Convert my existing reminders, scheduled dispatches, check-ins, etc.

3. **Preserve everything** — don't drop any tasks, decisions, or context from my existing files. If something doesn't fit the format, add it to the appropriate section's notes.

4. **Ask me** if anything is unclear about my existing setup before generating.

---

## My existing files

_(Share your files below this line, or upload them)_
