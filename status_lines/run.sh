#!/usr/bin/env bash
# Wrapper for the status line script.
#
# Claude Code spawns this in a shell that does not necessarily have the user's
# interactive PATH, so `uv` installed to ~/.local/bin (standalone installer) or
# under Homebrew can be invisible here even though `command -v uv` works fine in
# a terminal. A missing command yields EMPTY OUTPUT, which renders as "no status
# line" rather than an error — indistinguishable from a broken script.
#
# So: look in the known locations, and if uv genuinely isn't there, say so in
# the status line itself instead of failing silently.

set -uo pipefail
SCRIPT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/status_line_powerline.py"

find_uv() {
  command -v uv 2>/dev/null && return 0
  for c in /opt/homebrew/bin/uv /usr/local/bin/uv "$HOME/.local/bin/uv" \
           "$HOME/.cargo/bin/uv" /opt/homebrew/opt/uv/bin/uv; do
    [ -x "$c" ] && { printf '%s' "$c"; return 0; }
  done
  return 1
}

UV="$(find_uv)" || {
  printf '\033[38;5;203m uv not found — brew install uv \033[0m'
  exit 0
}

exec "$UV" run --script "$SCRIPT"
