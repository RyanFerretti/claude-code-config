# .claude

My personal [Claude Code](https://claude.ai/claude-code) configuration. This repo contains the custom rules, agents, skills, and status line scripts I use daily.

## What's Here

- **CLAUDE.md** - Global instructions that apply to every project (safety rails, tmux conventions, model preferences)
- **settings.json** - Claude Code settings including custom status line config
- **agents/** - Custom sub-agent definitions (e.g., meta-agent for generating new agents)
- **rules/** - Reusable rules for common workflows (e.g., tmux dev server management)
- **skills/** - Custom skills for code review, PRD review, frontend design, and more
- **status_lines/** - Python script for a custom status line with context usage, session cost, git branch, tmux server status, and last-active timestamps

## Status Line

The status line shows at a glance:

- Project name and git branch
- Model name
- Context window usage with color-coded progress bar (green/yellow/red)
- Session cost
- Session duration
- Last active timestamp (useful when juggling multiple tabs)
- Running tmux dev servers for the current project

## Setup

This repo lives at `~/.claude`. If you want to use any of these configs:

```bash
git clone <repo-url> ~/.claude
```

The status line requires [uv](https://github.com/astral-sh/uv) for running the Python script.
