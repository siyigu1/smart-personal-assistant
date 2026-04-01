# Architecture v2 — Feature Requirements & Data Flow

## Design Principles

1. **Framework is the product.** The markdown files are standalone — usable with any LLM client without the daemon. Everything the LLM needs to serve the user is in the framework folder.

2. **Two systems, clear boundary.** The daemon is deterministic code (strict, reliable, zero tokens). The LLM is intelligent but unpredictable (needs error tolerance on both input and output).

3. **Contract-based communication.** Daemon and LLM communicate through well-defined contracts: JSON for LLM responses, markdown for context, JSON for scheduling. If LLM output doesn't match the contract, daemon falls back gracefully.

4. **Dual-source scheduling.** Scheduled events exist in TWO places:
   - `Automations.md` — human/LLM readable (the framework file, works without daemon)
   - `automations.json` — machine readable (daemon reads this directly, no parsing ambiguity)
   - The LLM writes to `.md`, the daemon syncs to `.json`. Or: setup generates both.

---

## System Diagram

```
┌─────────────────────────────────────────────────────────────────────┐
│                         FRAMEWORK (standalone)                       │
│                                                                      │
│  Markdown files in user's folder — works with ANY LLM               │
│                                                                      │
│  ┌──────────────┐ ┌──────────────┐ ┌──────────────┐                │
│  │ START HERE   │ │ Workstreams  │ │ Weekly Goals  │                │
│  │ .md          │ │ .md          │ │ .md           │                │
│  └──────────────┘ └──────────────┘ └──────────────┘                │
│  ┌──────────────┐ ┌──────────────┐ ┌──────────────┐                │
│  │ Daily        │ │ Preferences  │ │ Automations   │                │
│  │ Scaffolding  │ │ .md          │ │ .md           │                │
│  └──────────────┘ └──────────────┘ └──────────────┘                │
│  ┌──────────────┐ ┌──────────────┐ ┌──────────────┐                │
│  │ Cognitive    │ │ Priority     │ │ Playbook      │                │
│  │ Levels.md    │ │ Framework.md │ │ .md           │                │
│  └──────────────┘ └──────────────┘ └──────────────┘                │
│                                                                      │
│  Memory layer (also markdown, also standalone):                      │
│  ┌──────────────┐ ┌──────────────┐                                  │
│  │ Preferences  │ │ Grocery List │                                  │
│  │ .md (long)   │ │ .md          │                                  │
│  └──────────────┘ └──────────────┘                                  │
└─────────────────────────────────────────────────────────────────────┘
          │                                           ▲
          │ Framework files (read)                    │ File updates (write)
          ▼                                           │
┌─────────────────────────────────────────────────────────────────────┐
│                         DAEMON (deterministic)                       │
│                                                                      │
│  ┌─────────────────────────────────────────────────────────────┐    │
│  │                    Main Loop (every 60s)                     │    │
│  │                                                              │    │
│  │  Per user (round-robin):                                     │    │
│  │    1. Fire due reminders ──────────── reminders.json         │    │
│  │    2. Check scheduled events ──────── automations.json       │    │
│  │       ├─ type: "message" ──→ post directly (zero tokens)    │    │
│  │       ├─ type: "cached"  ──→ post from cache file           │    │
│  │       └─ type: "llm"    ──→ invoke LLM (see below)          │    │
│  │    3. Poll Slack for new messages                            │    │
│  │       └─ new message? ──→ invoke LLM (see below)            │    │
│  │    4. Check cross-tasks                                      │    │
│  │    5. Periodic maintenance (see below)                       │    │
│  └─────────────────────────────────────────────────────────────┘    │
│                                                                      │
│  ┌────────────────────┐  ┌────────────────────┐                     │
│  │ automations.json   │  │ reminders.json      │                    │
│  │ (strict, daemon-   │  │ (strict, daemon-    │                    │
│  │  readable)         │  │  readable)          │                    │
│  └────────────────────┘  └────────────────────┘                     │
│  ┌────────────────────┐  ┌────────────────────┐                     │
│  │ cache/             │  │ .short-term-        │                    │
│  │ (pre-generated     │  │  memory.json        │                    │
│  │  LLM responses)    │  │ (7-day TTL)         │                    │
│  └────────────────────┘  └────────────────────┘                     │
└──────────────────┬──────────────────────────────────────────────────┘
                   │
                   │ Invoke LLM (only when intelligence needed)
                   ▼
┌─────────────────────────────────────────────────────────────────────┐
│                     ERROR TOLERANCE LAYER                            │
│                                                                      │
│  Input assembly (daemon → LLM):                                     │
│    - Read framework .md files                                       │
│    - Strip noise (comments, instructions, placeholders)             │
│    - Load short-term memory (strip timestamps)                      │
│    - Load conversation history (compact old messages)               │
│    - Attach operation-specific prompt                               │
│    - Format: plain text prompt via stdin                            │
│                                                                      │
│  Output parsing (LLM → daemon):                                     │
│    - Extract JSON from response (brace-counting, ignore wrappers)   │
│    - Validate required fields (messages, files, etc.)               │
│    - Fallback: if no valid JSON, treat as plain text message        │
│    - Strip internal markers (ONBOARDING_COMPLETE)                   │
│    - Normalize filenames ("Workstreams" → "Workstreams.md")         │
│                                                                      │
│  Error handling:                                                     │
│    - Auth failure → notify user via Slack (once per error type)     │
│    - Empty response → notify user, retry next cycle                 │
│    - Malformed JSON → use raw text as message, skip file updates    │
│    - Timeout → log, retry next cycle                                │
└──────────────────┬──────────────────────────────────────────────────┘
                   │
                   ▼
┌─────────────────────────────────────────────────────────────────────┐
│                          LLM (intelligent)                           │
│                                                                      │
│  Receives: prompt + context files + memory + user message           │
│  Returns: JSON { messages, files, short_term_memory,                │
│                   onboarding_complete }                              │
│                                                                      │
│  Operation types:                                                    │
│                                                                      │
│  A. Scheduled operations (dispatch, check-in, EOD, weekly)          │
│     Input: fixed prompt + framework files                           │
│     Output: message only (no file updates expected)                 │
│     → Daemon posts message to Slack                                 │
│     → Optional: daemon caches response for future reuse             │
│                                                                      │
│  B. User message response                                           │
│     Input: user message + framework files + memory                  │
│     Output: message + file updates + memory updates                 │
│     Three actions:                                                   │
│       1. Respond to user (message → Slack)                          │
│       2. Update context files (files → disk)                        │
│       3. Update short-term memory (short_term_memory → .json)       │
│                                                                      │
│  C. Periodic maintenance (triggered by daemon, no user input)       │
│     c1. Memory consolidation (every 7 days):                        │
│         - Read short-term memory                                    │
│         - Move important items to Preferences.md (long-term)        │
│         - Prune stale short-term entries                            │
│     c2. Context tidying (every 7 days or on demand):                │
│         - Read all framework files                                  │
│         - Reorganize, deduplicate, clean up formatting              │
│         - Rewrite files with clean content                          │
│                                                                      │
│  D. Onboarding (first run)                                          │
│     Input: Getting Started.md + conversation history                │
│     Output: message + file updates (when complete)                  │
│     Multi-turn with conversation state tracking                     │
└─────────────────────────────────────────────────────────────────────┘
```

---

## Feature Requirements

### F1: Slack Listener
**Owner:** Daemon
**Description:** Poll Slack channel for new messages every 60 seconds.
**Input:** Slack API (channel history)
**Output:** New message text (if any) → passed to LLM
**Error handling:** Slack API failure → log, retry next cycle

### F2: Scheduled Events
**Owner:** Daemon
**Description:** Fire events at specific times based on `automations.json`.
**Three event types:**

| Type | What happens | Tokens |
|------|-------------|--------|
| `message` | Daemon posts text directly to Slack | 0 |
| `cached` | Daemon posts from a pre-generated cache file | 0 |
| `llm` | Daemon invokes LLM with a fixed prompt, posts response | ~2-5K |

**Dual-source config:**
- `Automations.md` — human/LLM readable, part of the framework. Users and LLMs read/write this.
- `automations.json` — machine readable, daemon reads this. Strict format, no parsing ambiguity.
- Sync: when LLM updates `Automations.md`, daemon re-parses it into `automations.json` on next cycle. Or: daemon watches the .md file mtime and syncs when changed.

**automations.json format:**
```json
[
  {
    "time": "08:00",
    "days": ["mon","tue","wed","thu","fri"],
    "type": "llm",
    "name": "Morning dispatch",
    "prompt": "Generate the morning dispatch..."
  },
  {
    "time": "16:30",
    "days": ["mon","tue","wed","thu","fri"],
    "type": "message",
    "name": "Kid pickup",
    "text": "Reminder: kid pickup in 20 minutes!"
  },
  {
    "time": "07:00",
    "days": ["mon","tue","wed","thu","fri"],
    "type": "cached",
    "name": "Weather brief",
    "cache_file": ".cache/weather-brief.txt"
  }
]
```

### F3: Reminders
**Owner:** Daemon
**Description:** Fire due reminders from `reminders.json`. Pure code, zero tokens.
**Input:** reminders.json (timestamp + message)
**Output:** Post message to Slack
**Note:** LLM adds reminders by including reminders.json in its file updates.

### F4: Response Caching (new)
**Owner:** Daemon + LLM
**Description:** LLM can pre-generate responses that daemon fires later without re-invoking LLM.
**Use case:** During evening summary, LLM generates tomorrow's morning dispatch draft and saves to `.cache/morning-dispatch-draft.txt`. Next morning, daemon posts it directly (0 tokens) instead of invoking LLM. If user then replies, LLM handles the reply normally.
**Contract:** LLM writes to `files` with key `cache/[name]`, daemon saves to `.cache/` directory and can reference in automations.

### F5: User Message Response
**Owner:** LLM (invoked by daemon)
**Description:** Respond to user messages with intelligence.
**Input:** User message + framework files + short-term memory + conversation history
**Output (3 actions):**
1. `messages` → daemon posts to Slack
2. `files` → daemon writes to disk (context files, Preferences, etc.)
3. `short_term_memory` → daemon saves to .short-term-memory.json

### F6: Memory System
**Owner:** LLM (managed by daemon lifecycle)

**Three tiers:**

| Tier | File | TTL | What goes here | Who writes |
|------|------|-----|----------------|------------|
| Conversation | .conversation-state.json | 2 hours | Full chat log for multi-turn flows | Daemon |
| Short-term | .short-term-memory.json | 7 days | Context between messages (partial answers, state) | LLM via JSON response |
| Long-term | Preferences.md + framework files | Permanent | User preferences, project data, schedule | LLM via JSON response |

**Memory consolidation (F6a):**
- **Trigger:** Daemon runs this every 7 days (or configurable)
- **Process:** Invoke LLM with prompt: "Review short-term memory. Move anything important to Preferences.md or relevant framework files. Prune stale entries."
- **User-facing:** Invisible. User never triggers this manually.

### F7: Context Tidying
**Owner:** LLM (triggered by daemon or user)
**Description:** Periodically reorganize and clean up framework files.
**Trigger:**
- Automatic: every 7 days (daemon schedules this)
- Manual: user says "tidy up my files" or "reorganize workstreams"
**Process:** LLM reads all framework files, rewrites them with clean formatting, removes stale entries, deduplicates, reorganizes.
**Output:** Updated files via `files` in JSON response.

### F8: LLM Auth Detection
**Owner:** Daemon
**Description:** Detect LLM authentication failures and notify user.
**Behavior:** On 401/auth error → post to Slack (once): "I need you to log in. Run: claude login"
**Already implemented.**

### F9: System Update Check
**Owner:** Daemon (prefer no LLM)
**Description:** Check if macOS/system has pending updates.
**Implementation options:**
- macOS: `softwareupdate -l` → parse output for available updates (no LLM needed)
- Cross-platform: read system update status via OS-specific commands
**Output:** If updates available → post to Slack: "macOS update available: [version]. Install when convenient."
**Frequency:** Daily at a quiet time (e.g., 3am)

### F10: Cross-Task Delegation
**Owner:** Daemon + LLM
**Description:** Users can assign tasks to family members.
**Flow:**
1. User says "add 倒垃圾 to Hao's list" → LLM writes to cross-tasks.json
2. Daemon checks cross-tasks.json on Hao's cycle → posts notification
3. Hao accepts/rejects → LLM updates cross-tasks.json
**Already implemented.**

### F11: Multi-User Support
**Owner:** Daemon
**Description:** Round-robin polling of multiple user channels.
**Behavior:** One user per cycle. With N users, each gets polled every N minutes.
**Each user has independent:** channel, notes folder, conversation, memory, reminders, automations, preferences.
**Already implemented.**

---

## Data Flow Summary

### Scheduled Event (e.g., Morning Dispatch)

```
automations.json          daemon                    LLM
     │                      │                        │
     │── time match? ──────→│                        │
     │                      │── type: "llm" ────────→│
     │                      │   (fixed prompt +       │
     │                      │    framework files)     │
     │                      │                        │── generates dispatch
     │                      │←── JSON response ──────│
     │                      │                        │
     │                      │── parse JSON            │
     │                      │── post message → Slack  │
     │                      │── (no file updates      │
     │                      │    expected)            │
```

### User Message Response

```
Slack                daemon              error layer           LLM
  │                    │                      │                  │
  │── new message ────→│                      │                  │
  │                    │── ack "收到" → Slack  │                  │
  │                    │                      │                  │
  │                    │── build prompt ──────→│                  │
  │                    │   (framework files    │                  │
  │                    │    + STM + conv        │                  │
  │                    │    + user msg)         │── invoke ──────→│
  │                    │                      │                  │
  │                    │                      │←── JSON ─────────│
  │                    │                      │                  │
  │                    │←── parsed response ──│                  │
  │                    │                      │                  │
  │←── message ────────│                      │                  │
  │                    │── write files → disk  │                  │
  │                    │── save STM → .json    │                  │
```

### Memory Consolidation (periodic)

```
daemon                              LLM
  │                                   │
  │── (7-day timer fires)             │
  │── build prompt:                   │
  │   "Review STM, move important     │
  │    items to Preferences.md,       │──→│
  │    prune stale entries"           │   │
  │                                   │   │── reviews memory
  │                                   │   │── updates Preferences.md
  │←── JSON (files + cleared STM) ────│   │
  │                                   │
  │── write Preferences.md            │
  │── prune STM                       │
```

---

## Implementation Priority

1. **Fix automations.json** (F2) — daemon reads strict JSON, not ambiguous markdown table
2. **Response caching** (F4) — LLM pre-generates, daemon fires at 0 cost
3. **Memory consolidation** (F6a) — STM → long-term every 7 days
4. **Context tidying** (F7) — periodic cleanup of framework files
5. **System update check** (F9) — `softwareupdate -l` parsing
6. **Everything else** — already implemented or minor

---

## Framework Independence

The framework folder must always work standalone. This means:

| Data | Framework (.md) | Daemon (.json) | Who writes which |
|------|-----------------|----------------|------------------|
| Automations | Automations.md (human readable) | automations.json (machine readable) | LLM writes .md, daemon syncs to .json |
| Reminders | _(in Automations.md for recurring)_ | reminders.json | LLM writes .json via file updates |
| Preferences | Preferences.md | _(none, .md is the source)_ | LLM writes .md |
| Schedule | Daily Scaffolding.md | _(none, .md is the source)_ | LLM writes .md |

When a user gives the framework to ChatGPT (no daemon), everything works via the .md files. The .json files are daemon-only optimization.
