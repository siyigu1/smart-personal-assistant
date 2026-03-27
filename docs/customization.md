# Customization Guide

After running setup, everything is plain markdown files. Modify them directly.

## Adding Workstreams

Edit `Workstreams.md`. Add a new section following this format:

```markdown
## N. Your New Project
- **Phase:** planning / active / maintenance
- **Cognitive Level:** L1 / L2 / L3 / L1-L2 mix
- **Status:** In progress
- **Next Milestone:** [description]
- **Pick-Up Packet:**
  - [Context for resuming this workstream]
- **Decisions Log:**
  - [Key decisions]

### Pending Tasks
- **[L1] Task name** — details

### Completed
```

Then update the priority order at the top of the file.

## Changing Your Schedule

Edit `Daily Scaffolding.md`. Update the time blocks, fixed commitments, and deep work blocks. The agent reads this file every cycle, so changes take effect immediately.

## Modifying Agent Behavior

The agent's behavior is defined in `skills/mission-control/SKILL.md`. Key sections you might want to modify:

- **Important Rules** — Add or remove rules (e.g., "never suggest work after 8pm")
- **Night-time Rules** — Adjust the night behavior
- **Ad-Hoc Interaction Patterns** — Add new command patterns the agent should recognize
- **Planning Rules** — Change the L1/L2 parallelism rules

## Adding Grocery Stores

Edit `Grocery List.md`. Add new store sections and update the Category Rules at the bottom.

## Adding Trips

Edit `Travel Master List.md`. Add trips in the Upcoming Trips section. The agent will auto-generate packing lists 14 days before departure.

## Modifying Scheduled Task Prompts

Each scheduled task has its own SKILL.md at `~/.claude/scheduled-tasks/<task-name>/SKILL.md`. You can modify:

- The task description
- Specific instructions for that operation
- Which files it reads

Changes take effect on the next run.

## Re-Running Setup

Run `./setup.sh` again. It will detect the existing `.mc-config.json` and offer update mode. Your custom content in state files (tasks, decisions, completed items) is preserved.
