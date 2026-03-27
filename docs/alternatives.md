# Alternative Setup Paths

Mission Control's core is agent-agnostic: plain markdown state files + a text-based system prompt. You can use it with different platforms.

## Option 1: With OpenClaw

If you already run [OpenClaw](https://github.com/openclaw/openclaw):

1. Copy the state file templates to your OpenClaw workspace:
   ```bash
   cp templates/core/en/*.md /path/to/openclaw/workspace/
   cp templates/core/en/*.tpl /path/to/openclaw/workspace/  # rename .tpl to .md
   ```

2. Add the system prompt as an OpenClaw skill:
   ```bash
   cp templates/prompts/en/system-prompt.md.tpl /path/to/openclaw/skills/mission-control.md
   ```

3. Configure a cron job in OpenClaw's Gateway for morning dispatch, check-ins, etc.

4. OpenClaw's built-in channel adapters handle Slack/WhatsApp/Discord — no separate Slack App needed.

The state files are plain markdown — OpenClaw reads and writes them the same way our daemon does.

## Option 2: Claude Desktop Scheduled Tasks (No Daemon)

If you prefer everything inside Claude with no external daemon:

```bash
./setup.sh --mode cowork
```

This generates SKILL.md files in `~/.claude/scheduled-tasks/` that Claude Desktop runs on a schedule. You configure timing in the Desktop app's Schedule tab.

**Trade-offs vs. daemon mode:**

| | Daemon Mode | Cowork Mode |
|---|---|---|
| Daily tokens | ~15-20K | ~60-80K |
| Setup complexity | Medium (Slack App + Python) | Low (just Claude Desktop) |
| Requires | Python 3.10+, always-on machine | Claude Desktop running |
| Slack integration | Slack SDK (bot token) | Slack MCP (built into Claude) |
| Speed | Instant for polling | ~5s session spin-up each cycle |

## Option 3: Conversational Setup (No Script)

Load the setup skill directly in any Claude session:

1. Start Claude Code or Claude Desktop
2. Say: "Load the file at `/path/to/smart-personal-assistant/skills/setup/SKILL.md`"
3. Claude walks you through the same setup conversationally
4. It generates all files using its Write tool

This is great if you don't want to run a bash script or if you want to customize things interactively.

## Option 4: Any LLM with API Access

The system prompt is pure text. Any LLM that can:
1. Accept a long text prompt (~5-10K tokens)
2. Return structured text output
3. Be invoked from a script

...can power Mission Control. You'd need to:
1. Create a new LLM bridge in `daemon/llm/` (implement the `LLMBridge` interface)
2. Set `llm_provider` in your config

Example: Ollama (free, local):
```python
# daemon/llm/ollama.py
class OllamaLLM(LLMBridge):
    def invoke(self, prompt: str) -> str:
        response = requests.post("http://localhost:11434/api/generate",
            json={"model": "llama3", "prompt": prompt})
        return response.json()["response"]
```
