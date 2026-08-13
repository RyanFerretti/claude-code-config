# .claude

My personal [Claude Code](https://code.claude.com/docs/en/overview) configuration. This repo contains the custom rules, agents, skills, and status line scripts I use daily.

## What's Here

- **CLAUDE.md** - Global instructions that apply to every project (safety rails, tmux conventions, model preferences)
- **settings.json** - Claude Code settings including custom status line config
- **bootstrap.sh** - One-shot setup for a new macOS machine (see below)
- **agents/** - Custom sub-agent definitions (e.g., meta-agent for generating new agents)
- **rules/** - Reusable rules for common workflows (e.g., tmux dev server management)
- **agents-skills/** - Hand-written skills with no upstream, installed to `~/.agents/skills`
- **agents-skill-lock.json** - Pinned upstream sources for the rest of `~/.agents/skills`
- **skills/** - A few self-contained skills; the rest are symlinks into `~/.agents/skills`
- **status_lines/** - Python script for a custom status line with context usage, session cost, git branch, tmux server status, and last-active timestamps

## What is *not* here

This repo is **public**, so it deliberately excludes:

- **Secrets** — no API keys, tokens, or credentials
- **Memories** — `~/.claude/projects/*/memory/` is client-internal
- **Client-specific skills** — e.g. `bc-integration` documents a client's ERP tenant

`skills/` is whitelisted per-skill in `.gitignore` rather than wholesale, so a new
client skill never gets published by accident.

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

This repo lives at `~/.claude`. On a fresh macOS machine:

```bash
curl -fsSL https://raw.githubusercontent.com/RyanFerretti/claude-code-config/master/bootstrap.sh | bash
```

`bootstrap.sh` is idempotent and never deletes untracked files in `~/.claude`. It
installs prerequisites, wires `~/.claude` up as this repo (preserving Claude Code's
existing runtime state), restores `~/.agents/skills` from the lockfile plus the
vendored skills, relinks `~/.claude/skills`, and verifies the result.

Flags:

| Flag | Effect |
|---|---|
| `--managed` | Corporate/MDM device: strips the local-only `ccdash` hooks and drops `skipDangerousModePermissionPrompt` |
| `--skip-brew` | Leave Homebrew packages alone |
| `--verify` | Report state, change nothing |
| `--dry-run` | Print what would happen |

Run `--verify` first on an existing machine to see what's missing.

The status line requires [uv](https://github.com/astral-sh/uv) and a Nerd Font in
your terminal — without either it renders as blanks or tofu.
