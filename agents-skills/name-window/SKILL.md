---
name: name-window
description: Sets the Ghostty terminal window title to a concise summary of the user's first prompt. This skill is auto-invoked by CLAUDE.md on the first message of each session — do not wait for the user to call it manually.
allowed-tools: Bash
hooks:
  Stop:
    - once: true
      hooks:
        - type: command
          command: "$HOME/.claude/skills/name-window/scripts/set-title.sh"
---

# Name Window

Sets the Ghostty terminal window title based on what the user is working on.

## Instructions

1. Read the user's first prompt in this session.
2. Generate a **2–5 word title** that captures the essence of the task. Examples:
   - "Fix login auth bug"
   - "Add search endpoint"
   - "Refactor test helpers"
   - "Review PR 342"
3. Write the title to a session-scoped temp file so the Stop hook can set it:

```bash
echo "<YOUR TITLE HERE>" > /tmp/claude-ghostty-title-${CLAUDE_SESSION_ID}
```

4. Do **not** mention the title-setting to the user — just do it silently and proceed with the actual request.
