#!/usr/bin/env bash
#
# bootstrap.sh — reproduce this Claude Code environment on a new macOS machine.
#
#   curl -fsSL https://raw.githubusercontent.com/RyanFerretti/claude-code-config/master/bootstrap.sh | bash -s -- --managed
#
# or, once the repo is cloned to ~/.claude:
#
#   ~/.claude/bootstrap.sh [--managed] [--skip-brew] [--verify] [--dry-run]
#
# Flags:
#   --managed    Corporate/MDM device: strips ccdash hooks, drops
#                skipDangerousModePermissionPrompt, skips personal-only skills.
#   --skip-brew  Don't touch Homebrew packages.
#   --verify     Report state only; change nothing.
#   --dry-run    Print what would happen.
#
# Idempotent: safe to re-run. Never deletes untracked files in ~/.claude.

set -euo pipefail

REPO_URL="https://github.com/RyanFerretti/claude-code-config.git"
CLAUDE_DIR="$HOME/.claude"
AGENTS_DIR="$HOME/.agents"
MANAGED=0 SKIP_BREW=0 VERIFY=0 DRY=0

for arg in "$@"; do
  case "$arg" in
    --managed)   MANAGED=1 ;;
    --skip-brew) SKIP_BREW=1 ;;
    --verify)    VERIFY=1 ;;
    --dry-run)   DRY=1 ;;
    -h|--help)   sed -n '2,20p' "$0"; exit 0 ;;
    *) echo "unknown flag: $arg" >&2; exit 2 ;;
  esac
done

say()  { printf '\033[1;34m==>\033[0m %s\n' "$*"; }
ok()   { printf '  \033[32m✓\033[0m %s\n' "$*"; }
warn() { printf '  \033[33m!\033[0m %s\n' "$*"; }
bad()  { printf '  \033[31m✗\033[0m %s\n' "$*"; }
run()  { if [ "$DRY" = 1 ] || [ "$VERIFY" = 1 ]; then printf '  [dry] %s\n' "$*"; else eval "$@"; fi; }

# ── 0. preflight ────────────────────────────────────────────────────────────
say "Preflight"
[ "$(uname -s)" = "Darwin" ] || { bad "macOS only"; exit 1; }
ok "macOS $(sw_vers -productVersion), user=$USER, home=$HOME"

MANAGED_SETTINGS="/Library/Application Support/ClaudeCode/managed-settings.json"
if [ -f "$MANAGED_SETTINGS" ]; then
  warn "Managed settings present — these OVERRIDE everything below:"
  sed 's/^/      /' "$MANAGED_SETTINGS"
  warn "If hooks/MCP/plugins are disabled there, parts of this setup won't apply."
else
  ok "No managed-settings.json (org policy not pushed to this device)"
fi

[ "$MANAGED" = 1 ] && ok "Managed mode: ccdash hooks + permission-bypass will be stripped"

# ── 1. prereqs ──────────────────────────────────────────────────────────────
say "Prerequisites"
BREW_PKGS=(git gh tmux ripgrep jq starship fnm uv)
CASKS=(ghostty font-meslo-lg-nerd-font)

if [ "$SKIP_BREW" = 1 ]; then
  warn "Skipping Homebrew (--skip-brew)"
else
  if ! command -v brew >/dev/null 2>&1; then
    warn "Homebrew missing. Install it first:"
    echo '      /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"'
  else
    for p in "${BREW_PKGS[@]}"; do
      if brew list --formula "$p" >/dev/null 2>&1; then ok "$p"
      else warn "installing $p"; run "brew install $p"; fi
    done
    for c in "${CASKS[@]}"; do
      if brew list --cask "$c" >/dev/null 2>&1; then ok "$c"
      else warn "installing $c"; run "brew install --cask $c"; fi
    done
  fi
fi

# bun is not from brew
if command -v bun >/dev/null 2>&1; then ok "bun $(bun --version)"
else warn "installing bun"; run 'curl -fsSL https://bun.sh/install | bash'; fi

# uv drives the status line; without it the status line silently dies
command -v uv >/dev/null 2>&1 && ok "uv $(uv --version | awk '{print $2}')" || bad "uv MISSING — status line will not render"

# ── 2. Claude Code ──────────────────────────────────────────────────────────
say "Claude Code"
if command -v claude >/dev/null 2>&1; then
  ok "claude $(claude --version 2>/dev/null | awk '{print $1}')"
else
  warn "not installed — native installer:"
  echo '      curl -fsSL https://claude.ai/install.sh | bash'
fi

# ── 3. ~/.claude config repo ────────────────────────────────────────────────
say "Config repo → $CLAUDE_DIR"
mkdir -p "$CLAUDE_DIR"
if git -C "$CLAUDE_DIR" rev-parse --git-dir >/dev/null 2>&1; then
  ok "already a git repo ($(git -C "$CLAUDE_DIR" remote get-url origin 2>/dev/null || echo 'no remote'))"
  run "git -C '$CLAUDE_DIR' fetch origin master --quiet"
  if [ -n "$(git -C "$CLAUDE_DIR" status --porcelain 2>/dev/null)" ]; then
    warn "local changes present — not auto-merging. Resolve manually:"
    git -C "$CLAUDE_DIR" status --short | sed 's/^/      /'
  else
    run "git -C '$CLAUDE_DIR' merge --ff-only origin/master --quiet"
  fi
else
  # ~/.claude exists (Claude Code created it) but isn't the repo yet.
  # init + fetch + checkout writes ONLY tracked files; untracked runtime
  # state (projects/, todos/, history.jsonl, …) is left untouched.
  if [ -f "$CLAUDE_DIR/settings.json" ]; then
    STAMP=$(date +%Y%m%d-%H%M%S)
    warn "backing up existing settings.json → settings.json.pre-bootstrap-$STAMP"
    run "cp '$CLAUDE_DIR/settings.json' '$CLAUDE_DIR/settings.json.pre-bootstrap-$STAMP'"
  fi
  run "git -C '$CLAUDE_DIR' init -b master --quiet"
  run "git -C '$CLAUDE_DIR' remote add origin '$REPO_URL'"
  run "git -C '$CLAUDE_DIR' fetch origin master --quiet"
  run "git -C '$CLAUDE_DIR' checkout -f master"
  ok "config repo checked out"
fi

# ── 4. ~/.agents/skills ─────────────────────────────────────────────────────
# Two sources: upstream skills pinned in agents-skill-lock.json, and the
# hand-written ones vendored in agents-skills/ (no upstream to pull from).
say "Skills → $AGENTS_DIR/skills"
mkdir -p "$AGENTS_DIR/skills"

LOCK="$CLAUDE_DIR/agents-skill-lock.json"
if [ -f "$LOCK" ]; then
  [ -f "$AGENTS_DIR/.skill-lock.json" ] || run "cp '$LOCK' '$AGENTS_DIR/.skill-lock.json'"
  while IFS=$'\t' read -r name url skillpath; do
    [ -n "$name" ] || continue
    if [ -d "$AGENTS_DIR/skills/$name" ]; then ok "$name (present)"; continue; fi
    warn "installing $name from $url"
    if [ "$DRY" = 1 ] || [ "$VERIFY" = 1 ]; then continue; fi
    tmp=$(mktemp -d)
    if git clone --depth 1 --quiet "$url" "$tmp" 2>/dev/null; then
      src="$tmp/$(dirname "$skillpath")"
      if [ -d "$src" ]; then cp -R "$src" "$AGENTS_DIR/skills/$name"; ok "$name"
      else bad "$name — skillPath '$skillpath' not found in repo"; fi
    else
      bad "$name — clone failed ($url)"
    fi
    rm -rf "$tmp"
  done < <(python3 -c "
import json,sys
d=json.load(open('$LOCK'))
for n,s in (d.get('skills') or {}).items():
    print('\t'.join([n, s.get('sourceUrl',''), s.get('skillPath','')]))
")
else
  bad "agents-skill-lock.json missing from config repo"
fi

# vendored, no upstream — name-window is required by global CLAUDE.md
if [ -d "$CLAUDE_DIR/agents-skills" ]; then
  for d in "$CLAUDE_DIR"/agents-skills/*/; do
    n=$(basename "$d")
    if [ -d "$AGENTS_DIR/skills/$n" ]; then ok "$n (vendored, present)"
    else run "cp -R '$d' '$AGENTS_DIR/skills/$n'"; ok "$n (vendored)"; fi
  done
fi

# ── 5. symlink skills into ~/.claude/skills ─────────────────────────────────
say "Linking skills → $CLAUDE_DIR/skills"
mkdir -p "$CLAUDE_DIR/skills"
for d in "$AGENTS_DIR"/skills/*/; do
  n=$(basename "$d")
  link="$CLAUDE_DIR/skills/$n"
  if [ -L "$link" ]; then
    [ -e "$link" ] && ok "$n" || { warn "$n dangling — relinking"; run "ln -sfn '../../.agents/skills/$n' '$link'"; }
  elif [ -e "$link" ]; then
    warn "$n exists as a real dir — leaving alone"
  else
    run "ln -sfn '../../.agents/skills/$n' '$link'"; ok "$n (linked)"
  fi
done

# ── 6. settings.json for this machine ───────────────────────────────────────
say "settings.json"
if [ "$MANAGED" = 1 ] && [ "$VERIFY" != 1 ] && [ "$DRY" != 1 ]; then
  python3 - "$CLAUDE_DIR/settings.json" <<'PY'
import json,sys
p=sys.argv[1]
s=json.load(open(p))
# ccdash is a local 60MB build under Projects/personal — not on this machine.
hooks=s.get("hooks",{}); removed=0
for ev in list(hooks):
    kept=[]
    for entry in hooks[ev]:
        inner=[h for h in entry.get("hooks",[]) if "ccdash" not in h.get("command","")]
        removed += len(entry.get("hooks",[])) - len(inner)
        if inner: kept.append({**entry,"hooks":inner})
    if kept: hooks[ev]=kept
    else: del hooks[ev]
if hooks: s["hooks"]=hooks
else: s.pop("hooks",None)
# permission-bypass is a poor default on a DLP-monitored corporate endpoint
dropped = s.pop("skipDangerousModePermissionPrompt", None) is not None
json.dump(s, open(p,"w"), indent=2)
open(p,"a").write("\n")
print(f"  \033[32m✓\033[0m stripped {removed} ccdash hook(s)" + ("; dropped skipDangerousModePermissionPrompt" if dropped else ""))
PY
  warn "settings.json now differs from origin/master — don't commit it back from this machine"
else
  ok "left as-is (use --managed to strip ccdash + permission-bypass)"
fi

# ── 7. plugins ──────────────────────────────────────────────────────────────
say "Plugins"
echo "  Run inside Claude Code (marketplace already declared in settings.json):"
echo "      /plugin marketplace add tobi/qmd"
echo "      /plugin install qmd@qmd"

# ── 8. git identity ─────────────────────────────────────────────────────────
say "Git identity"
CUR_EMAIL=$(git config --global user.email 2>/dev/null || echo "unset")
ok "global user.email = $CUR_EMAIL"
if [ "$MANAGED" = 1 ]; then
  echo "  A managed device should default to the work identity, not the personal one:"
  echo "      git config --global user.name  '<name>'"
  echo "      git config --global user.email '<work address>'"
  echo "      git config --global init.defaultBranch master"
  warn "If you scope a work identity with includeIf gitdir:, verify the path"
  warn "actually matches where that work is checked out — a stale path fails"
  warn "silently and commits get authored with the personal address."
fi

# ── 9. verify ───────────────────────────────────────────────────────────────
say "Verify"
[ -f "$CLAUDE_DIR/CLAUDE.md" ]                        && ok "CLAUDE.md"        || bad "CLAUDE.md"
[ -f "$CLAUDE_DIR/rules/tmux-dev-server.md" ]         && ok "rules/"           || bad "rules/"
[ -f "$CLAUDE_DIR/agents/meta-agent.md" ]             && ok "agents/"          || bad "agents/"
[ -f "$CLAUDE_DIR/status_lines/status_line_powerline.py" ] && ok "status line" || bad "status line"
[ -e "$CLAUDE_DIR/skills/name-window" ]               && ok "name-window"      || bad "name-window (global CLAUDE.md depends on it)"
DANGLING=$(find "$CLAUDE_DIR/skills" -maxdepth 1 -type l ! -exec test -e {} \; -print 2>/dev/null | wc -l | tr -d ' ')
[ "$DANGLING" = "0" ] && ok "no dangling skill symlinks" || bad "$DANGLING dangling skill symlink(s)"

say "Not handled here (deliberately)"
cat <<'EOF'
  • Secrets — no API keys are stored in this public repo. See the secrets
    checklist in the private hq repo (setup/README.md) for which ones this
    machine actually needs. Do NOT copy other clients' keys onto it.
  • Memories — ~/.claude/projects/*/memory/ is not in this repo (public).
    Restore from the private repo: hq/setup/restore-memory.sh
  • Sign in to Claude Code with the account intended for THIS machine.
EOF
echo
say "Done."
