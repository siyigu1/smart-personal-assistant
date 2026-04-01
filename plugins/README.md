# Plugins

Plugins extend the assistant with additional features. Each plugin is a folder with a `playbook.md` that teaches the AI how to handle a specific domain.

## How Plugins Work

```
plugins/
├── en/                          ← English plugin playbooks
│   ├── grocery/
│   │   └── playbook.md
│   └── travel/
│       └── playbook.md
├── zh/                          ← Chinese plugin playbooks
│   ├── grocery/
│   │   └── playbook.md
│   └── travel/
│       └── playbook.md
└── [your_plugin]/               ← user-created (any language)
    └── playbook.md
```

The daemon loads plugins from `plugins/{user_language}/` first, then checks `plugins/` root for user-created plugins that haven't been translated.

When the daemon starts, it discovers all plugins and includes their playbooks in the AI's context. The AI creates user-specific data files in the user's Obsidian folder:

```
user's obsidian/
├── plugins/
│   ├── grocery/
│   │   └── my_grocery.md    ← user's grocery list (AI-managed)
│   ├── travel/
│   │   ├── my_packing_template.md
│   │   └── my_trips.md
│   └── [your_plugin]/
│       └── [data files]     ← AI creates based on playbook
```

## Creating a Plugin

1. Create a folder: `plugins/my_plugin/`
2. Create `playbook.md` with:
   - What the plugin does
   - How the AI should behave (triggers, responses)
   - What user data files to create and their format
3. Tell the bot: "I added a new plugin called my_plugin"
4. The bot reads the playbook and starts using it

## Plugin Playbook Template

```markdown
# [Plugin Name]

## What This Plugin Does
[Brief description]

## Installation
When this plugin is installed, add the following to the user's
Preferences.md under "Installed Plugins":
- [name]: [description]. Triggers: [list of phrases that activate this plugin]. → Follow [name] plugin playbook. Data: [list of data files].

## How the Assistant Should Behave
[Trigger phrases, expected behavior, response format]

## User Data Files
[What files to create, their format, where they live in plugins/[name]/]
```

The Installation section is required — it tells the AI exactly what to add to Preferences.md so the routing works. Without it, the AI won't know when to use the plugin.

## Built-in Plugins

- **grocery** — Shopping list organized by store type
- **travel** — Trip packing with scaling rules and pre-travel reminders
