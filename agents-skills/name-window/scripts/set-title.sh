#!/bin/bash
# Sets the Ghostty window title via OSC 2 escape sequence.
# Called by the name-window skill's dynamic Stop hook.
# Reads session_id from stdin JSON to find the session-scoped temp file.

SESSION_ID=$(cat | jq -r '.session_id // empty')
TITLE_FILE="/tmp/claude-ghostty-title-${SESSION_ID}"

[ -f "$TITLE_FILE" ] || exit 0

TITLE=$(cat "$TITLE_FILE")

[ -z "$TITLE" ] && exit 0

printf '\033]2;%s\007' "$TITLE" > /dev/tty 2>/dev/null

# Clean up
case "$TITLE_FILE" in
  /tmp/claude-ghostty-title-*) rm -f "$TITLE_FILE" ;;
esac

exit 0
