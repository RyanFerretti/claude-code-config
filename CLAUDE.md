## Ghostty Window Title
- On the **first message** of every session, silently invoke `/name-window` to set the terminal title. Do this before responding to the user's actual request. Do not mention it.

- NEVER RESET MY LOCAL DATABASE, IF YOU THINK WE NEED TO DO IT THEN TELL ME TO DO IT
- Don't ever run a destructive command without asking me first
- Do not run any AWS, GCP, or Azure CLI commands. Tell me and I will run them, or I will give you permission to run them one by one.

## Development Server Management

**ALWAYS use tmux for long-running development processes** (dev servers, test watchers, build processes, etc.)

### tmux Session Naming Convention
- **Format:** `<project-name>-<purpose>`
- Project name is the root directory name (from `pwd`)
- Examples: `agent-ap-server`, `agent-ap-test-runner`, `myproject-worker`

### Standard Workflow
1. **Check for existing session first:**
   ```bash
   tmux has-session -t <session-name> 2>/dev/null
   ```
   If exists, ask user: (a) attach, (b) kill & recreate, or (c) different name

2. **Create new session:**
   ```bash
   tmux new-session -d -s <session-name> "cd $(pwd) && <command>"
   ```

3. **Always inform the user** with:
   - Session name
   - How to attach: `tmux attach -t <session-name>`
   - How to detach: `Ctrl+B, then D`
   - How to view logs: `tmux capture-pane -t <session-name> -p | tail -n 20`

4. **Read logs programmatically when needed:**
   ```bash
   tmux capture-pane -t <session-name> -p | tail -n 50
   ```

**See full details:** `~/.claude/rules/tmux-dev-server.md`
- with openai, always use the newest models which are now gpt-5.1 , gpt-5-mini , gpt-5-nano ... stop using GPT-4o and the variants

## Temporary Files
- Always use a `./tmp` directory at the project root for temporary, debug, or scratch files that have no long-term value and should not be committed.
- Never leave temp/debug files scattered in the project directory.

## New Project Setup
- Ensure a `.gitignore` exists at the project root, seeded at minimum with:
  ```
  .DS_Store
  tmp/
  node_modules/
  .env*
  *.log
  ```
