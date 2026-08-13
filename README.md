# .claude

My personal [Claude Code](https://code.claude.com/docs/en/overview) configuration. This repo contains the custom rules, agents, skills, and status line scripts I use daily.

## What's Here

- **CLAUDE.md** - Global instructions that apply to every project (safety rails, tmux conventions, model preferences)
- **settings.json** - Claude Code settings including custom status line config
- **bootstrap.sh** - One-shot setup for a new macOS machine (see below)
- **agents/** - Custom sub-agent definitions (e.g., meta-agent for generating new agents)
- **rules/** - Reusable rules for common workflows (e.g., tmux dev server management)
- **terminal/** - Ghostty and starship configs plus the `~/.zshrc` block that makes them active
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

The status line requires [uv](https://github.com/astral-sh/uv) and a font with
Nerd Font glyphs. Ghostty's default font already includes them, so `terminal/`
deliberately does not set `font-family` — override it only with a Nerd Font
variant, or the status line and starship prompt turn to tofu.

### Shell

`terminal/zshrc-fragment.sh` is appended to `~/.zshrc` between marker comments —
`starship init`, `fnm env`, the bun PATH, and `~/.local/bin`. Re-running bootstrap
replaces the block in place rather than appending a second copy, and backs the
old file up to `~/.zshrc.pre-bootstrap`.

Without it the configs install but stay inert: `starship.toml` is present with no
prompt, and — more visibly — `uv` may be off PATH, which makes the Claude Code
status line render as **nothing at all** rather than erroring.

Deliberately excluded: API keys, and the `--dangerously-skip-permissions` aliases.

### Ghostty on macOS

Ghostty merges **both** of these:

```
~/.config/ghostty/config                                   (XDG)
~/Library/Application Support/com.mitchellh.ghostty/config (macOS)
```

Settings drift across the two — `/terminal-setup` writes its `shift+enter`
binding to the macOS path while hand-edits tend to land in the XDG one, so a
machine move silently loses half the setup. Everything is consolidated into
`terminal/ghostty.config`; bootstrap installs it to the XDG path and warns if
the macOS path still holds live settings.
