- NEVER RESET MY LOCAL DATABASE, IF YOU THINK WE NEED TO DO IT THEN TELL ME TO DO IT
- don't ever run a destructive command without asking me first
- do not run any AWS cli commands, tell me and I will run them

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