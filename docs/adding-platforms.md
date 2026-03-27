# Adding Platform Support

The system is designed with an agent-agnostic core and platform-specific adapters.

## Architecture

```
templates/
├── core/          # State files — agent-agnostic markdown
├── prompts/       # System prompt + playbook — agent-agnostic instructions
└── platforms/
    └── claude-desktop/   # Claude-specific wrappers
        ├── skill.md.tpl          # SKILL.md with Claude frontmatter
        └── scheduled/            # Scheduled task SKILL.md files
```

The **core** and **prompts** templates contain pure instructions that work with any AI agent. The **platform adapter** wraps these instructions in the platform's specific format and handles scheduling.

## Adding a New Platform

1. Create a new directory: `templates/platforms/<platform-name>/`

2. Create a wrapper that loads the system prompt:
   - For Claude: `skill.md.tpl` with YAML frontmatter
   - For Codex: could be a `codex.json` task definition
   - For others: whatever format the platform needs

3. Create scheduled task definitions in the platform's format

4. Update `setup.sh`:
   - Add the platform to the selection menu in `collect_platform()`
   - Add platform-specific file generation in `generate_scheduled_tasks()`

## What Each Platform Needs

The system requires:

1. **Read/write local files** — State files are markdown on disk
2. **Slack integration** — Post and read messages via Slack API
3. **Scheduling** — Run tasks on a timer (every 5 min, daily, weekly)
4. **Long context** — System prompt + state files can be 5-10K tokens

## Example: Codex Adapter (hypothetical)

```
templates/platforms/codex/
├── task.json.tpl              # Codex task definition
└── scheduled/
    └── ... (if Codex supports scheduling)
```

Since Codex runs in sandboxed cloud environments, it would need:
- State files synced to a git repo (not local disk)
- Slack integration via API calls (not MCP)
- A different scheduling mechanism

PRs adding platform support are welcome!
