#!/usr/bin/env -S uv run --script
# /// script
# requires-python = ">=3.11"
# dependencies = [
#     "python-dotenv",
# ]
# ///

import json
import os
import sys
from pathlib import Path
from datetime import datetime
from zoneinfo import ZoneInfo

try:
    from dotenv import load_dotenv
    load_dotenv()
except ImportError:
    pass  # dotenv is optional


def get_git_branch():
    """Get current git branch name."""
    try:
        import subprocess
        result = subprocess.run(
            ["git", "branch", "--show-current"],
            capture_output=True,
            text=True,
            cwd=Path.cwd()
        )
        if result.returncode == 0:
            return result.stdout.strip()
    except:
        pass
    return None


def get_project_name():
    """Get project name from directory."""
    return Path.cwd().name


def get_tmux_sessions():
    """Get tmux sessions and their status."""
    try:
        import subprocess
        result = subprocess.run(
            ["tmux", "list-sessions", "-F", "#{session_name}"],
            capture_output=True,
            text=True
        )
        if result.returncode == 0:
            sessions = result.stdout.strip().split('\n')
            return [s for s in sessions if s]  # Filter out empty strings
        return []
    except:
        return []


def get_port_from_tmux_session(session_name):
    """Extract port number from tmux session output."""
    try:
        import subprocess
        import re

        # Capture entire scrollback from the beginning
        result = subprocess.run(
            ["tmux", "capture-pane", "-t", session_name, "-p", "-S", "-"],
            capture_output=True,
            text=True
        )

        if result.returncode != 0:
            return None

        output = result.stdout

        # Try various port detection patterns
        patterns = [
            r'Local:\s+https?://localhost:(\d+)',  # Next.js style
            r'ready on port (\d+)',                 # Next.js alternative
            r'localhost:(\d+)',                      # Generic
            r'listening on.*:(\d+)',                # Express style
            r'server running at.*:(\d+)',           # Vite style
            r'http://127\.0\.0\.1:(\d+)',          # Alternative localhost
        ]

        for pattern in patterns:
            match = re.search(pattern, output, re.IGNORECASE)
            if match:
                return match.group(1)

        return None
    except:
        return None


# Cache for session ports
_session_port_cache = {}


def format_tmux_status():
    """Format tmux session status for display."""
    global _session_port_cache

    sessions = get_tmux_sessions()
    project = get_project_name()
    server_session_name = f"{project}-server"

    # Filter to only sessions belonging to this project
    project_sessions = [s for s in sessions if s.startswith(f"{project}-")]

    if not project_sessions:
        # Clear cache when no project sessions
        _session_port_cache.clear()
        return "\033[31m🔴 localhost\033[0m"

    # Check for project server session
    has_server = server_session_name in project_sessions
    other_sessions = [s for s in project_sessions if s != server_session_name]

    # Clean cache for sessions that no longer exist
    _session_port_cache = {k: v for k, v in _session_port_cache.items() if k in sessions}

    parts = []

    if has_server:
        # Check cache first
        if server_session_name not in _session_port_cache:
            # Try to detect port
            port = get_port_from_tmux_session(server_session_name)
            if port:
                _session_port_cache[server_session_name] = port

        # Format the server status
        if server_session_name in _session_port_cache:
            port = _session_port_cache[server_session_name]
            parts.append(f"\033[32m🟢 localhost:{port}\033[0m - \033[90mtmux attach -t {server_session_name}\033[0m")
        else:
            parts.append(f"\033[32m🟢 localhost\033[0m - \033[90mtmux attach -t {server_session_name}\033[0m")
    else:
        # Clear server from cache when not running
        _session_port_cache.pop(server_session_name, None)
        parts.append("\033[31m🔴 localhost\033[0m")

    # Handle other sessions
    if len(other_sessions) == 1:
        session_name = other_sessions[0]
        # Use test emoji for test-runner, otherwise generic indicator
        emoji = "🧪" if "test" in session_name.lower() else "⚙️"
        parts.append(f"\033[32m{emoji} {session_name}\033[0m")
    elif len(other_sessions) > 1:
        parts.append(f"\033[90m{len(other_sessions)}+ more\033[0m")

    return " | ".join(parts)


def generate_status_line(input_data):
    """Generate a simple status line that doesn't require session files."""
    # Get model name
    model_info = input_data.get("model") or {}
    model_name = model_info.get("display_name", "Claude")

    # Get cost info
    cost_info = input_data.get("cost") or {}
    total_cost = cost_info.get("total_cost_usd", 0)
    
    # Get git branch
    branch = get_git_branch()
    
    # Get project name
    project = get_project_name()
    
    # Get current time in CT (this is effectively "last active" since the script only runs on activity)
    ct = datetime.now(ZoneInfo("America/Chicago"))
    now = f"{ct.strftime('%-m/%-d')} - {ct.strftime('%-I:%M%p').lower()}"
    
    # Build status line
    parts = []

    # Project name - bright cyan
    parts.append(f"\033[96m[{project}]\033[0m")

    # Branch - yellow if not main/master, green if main/master, gray if no git
    if branch is None:
        parts.append(f"\033[90m⎇ no git\033[0m")
    elif branch in ["main", "master"]:
        parts.append(f"\033[32m⎇ {branch}\033[0m")
    else:
        parts.append(f"\033[33m⎇ {branch}\033[0m")
    
    # Model - blue
    parts.append(f"\033[34m{model_name}\033[0m")

    # Context usage - progress bar scaled to the autocompact threshold, not the raw context window.
    # This means the bar approaches 100% right as autocompaction would trigger, rather than topping
    # out at ~83% of the raw window.
    #
    # How Claude Code computes the autocompact threshold (derived from cli.js internals):
    #   Hz6(model) = context_window_size - min(max_output_tokens, OUTPUT_TOKEN_CAP)
    #   threshold  = Hz6(model) - COMPACT_BUFFER
    #
    # For Opus/Sonnet 4.6 at 200k:  200000 - 20000 - 13000 = 167000 tokens (~83.5%)
    # For Sonnet 4.6 at 1M (future): 1000000 - 20000 - 13000 = 967000 tokens (~96.7%)
    #
    # OUTPUT_TOKEN_CAP and COMPACT_BUFFER are Claude Code constants (not model-specific).
    # context_window_size comes dynamically from the input JSON, so this works across all models.
    # See also: CLAUDE_AUTOCOMPACT_PCT_OVERRIDE env var can override the threshold if set.
    OUTPUT_TOKEN_CAP = 20000
    COMPACT_BUFFER = 13000
    context_info = input_data.get("context_window") or {}
    if context_info:
        usage = context_info.get("current_usage") or {}
        window_size = context_info.get("context_window_size", 200000)
        tokens_used = (
            usage.get("input_tokens", 0) +
            usage.get("cache_creation_input_tokens", 0) +
            usage.get("cache_read_input_tokens", 0)
        )
        effective_limit = window_size - OUTPUT_TOKEN_CAP - COMPACT_BUFFER
        used_pct = int(tokens_used * 100 / effective_limit) if effective_limit > 0 else 0
        used_pct = min(used_pct, 100)

        # Color based on usage: green < 50%, yellow 50-75%, red > 75%
        if used_pct >= 75:
            color = "\033[38;5;160m"  # red
        elif used_pct >= 50:
            color = "\033[38;5;226m"  # yellow
        else:
            color = "\033[38;5;34m"   # green

        # Build progress bar (10 chars wide)
        bar_width = 10
        filled = int(bar_width * used_pct / 100)
        bar = "█" * filled + "░" * (bar_width - filled)
        parts.append(f"{color}{bar} {used_pct}%\033[0m")

    # Cost if available - magenta
    if total_cost > 0:
        parts.append(f"\033[35m${total_cost:.2f}\033[0m")

    # Session duration as h:mm
    duration_ms = cost_info.get("total_duration_ms", 0)
    if duration_ms > 0:
        total_mins = int(duration_ms / 60000)
        hours, mins = divmod(total_mins, 60)
        parts.append(f"\033[90m{hours}:{mins:02d}\033[0m")

    # Last active time - gray
    parts.append(f"\033[90m{now}\033[0m")

    # tmux session status
    parts.append(format_tmux_status())

    return " | ".join(parts)


def main():
    try:
        # Read JSON input from stdin
        input_data = json.loads(sys.stdin.read())

        # Generate status line
        status_line = generate_status_line(input_data)

        # Output the status line
        print(status_line)
        
        # Success
        sys.exit(0)
        
    except Exception as e:
        # Handle errors gracefully
        print(f"\033[31mStatus line error: {str(e)}\033[0m")
        sys.exit(0)


if __name__ == "__main__":
    main()