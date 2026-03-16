#!/bin/bash
# Reads a title from /tmp/claude-ghostty-title (written by the name-window skill)
# and sets the Ghostty window title via OSC 2 escape sequence.
# Runs as a Stop hook so it has TTY access.

TITLE_FILE="/tmp/claude-ghostty-title"

[ -f "$TITLE_FILE" ] || exit 0

TITLE=$(cat "$TITLE_FILE")

[ -z "$TITLE" ] && exit 0

printf '\033]2;%s\007' "$TITLE" > /dev/tty 2>/dev/null

# Clean up so title is only set on first stop
# Safety: only delete if path is exactly the expected /tmp file
if [ "$TITLE_FILE" = "/tmp/claude-ghostty-title" ]; then
  rm -f "$TITLE_FILE"
fi

exit 0
