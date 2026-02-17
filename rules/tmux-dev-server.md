# tmux Development Server Rule

## When to Use tmux

Use tmux sessions for any long-running development processes that benefit from shared visibility between Claude Code and the user, including:
- Development servers (Next.js, Vite, etc.)
- Test watchers
- Build processes
- Database services
- Any process where logs need to be monitored

## Session Naming Convention

**Always prepend with the Project Name**
- The Project name is simply the name of the project's root directory.
- It is the deepest directory listed in the path when running `pwd`

Use predictable, lowercase, hyphenated names:
- Dev server: `<project-name>-server`
- Test runner: `<project-name>-test-runner`
- Build watcher: `<project-name>-build-watcher`
- Custom processes: `<project-name>-<purpose>` (e.g., `myapp-worker`)

## Standard Workflow

### 1. Check for Existing Session

Before creating a new session, always check if one exists:

```bash
tmux has-session -t <session-name> 2>/dev/null
```

If session exists:
- Inform the user: "A tmux session '<session-name>' already exists."
- Ask if they want to: (a) attach to existing, (b) kill and recreate, or (c) use a different name
- Show how to view: `tmux capture-pane -t <session-name> -p | tail -n 20`

### 2. Create New Session

Create detached session with the command:

```bash
tmux new-session -d -s <session-name> "cd $(pwd) && <command>"
```

Example (for a project named "agent-ap"):
```bash
tmux new-session -d -s agent-ap-server "cd $(pwd) && bun run dev"
```

### 3. Inform the User

After creating the session, always provide:

```
✓ Dev server started in tmux session '<project-name>-server'

To view logs:
  tmux attach -t <project-name>-server

To detach without stopping (while attached):
  Press Ctrl+B, then D

To view last 20 lines (without attaching):
  tmux capture-pane -t <project-name>-server -p | tail -n 20
```

### 4. Reading Logs Programmatically

When you need to check logs or diagnose issues:

```bash
# Capture all output
tmux capture-pane -t <session-name> -p

# Capture last N lines
tmux capture-pane -t <session-name> -p | tail -n 50

# Search for errors
tmux capture-pane -t <session-name> -p | grep -i error

# Check if process is still running
tmux list-sessions | grep <session-name>
```

### 5. Cleanup

When the task is complete or before creating a new session:

```bash
# Kill specific session
tmux kill-session -t <session-name>

# List all sessions (to check what's running)
tmux list-sessions
```

Always ask the user if they want to keep the session running when you're done with a task.

## Best Practices

1. **One session per service** - Don't run multiple services in the same session
2. **Always inform the user** - Tell them the session name and how to attach
3. **Check before creating** - Avoid duplicate sessions
4. **Capture for debugging** - Use `tmux capture-pane` to read logs when investigating issues
5. **Clean up** - Remind users about cleanup, but let them decide when to kill sessions
6. **Use full paths** - Always `cd $(pwd)` in session command to ensure correct working directory

## Example Usage

Example for a project named "agent-ap":

```bash
# Starting a Next.js dev server
tmux new-session -d -s agent-ap-server "cd $(pwd) && bun run dev"

# Starting a test watcher
tmux new-session -d -s agent-ap-test-runner "cd $(pwd) && bun test --watch"

# Starting multiple services (separate sessions)
tmux new-session -d -s agent-ap-api "cd $(pwd) && bun run api"
tmux new-session -d -s agent-ap-worker "cd $(pwd) && bun run worker"
```

## Troubleshooting

If tmux is not installed, inform the user:

```
tmux is not installed. Install with:
  macOS: brew install tmux
  Linux: sudo apt-get install tmux  (Ubuntu/Debian)
          sudo yum install tmux      (CentOS/RHEL)
```

If session creation fails, check:
- Is tmux installed? (`tmux -V`)
- Does the command work outside tmux?
- Is there a port conflict?
