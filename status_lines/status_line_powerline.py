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


# Powerline characters
PL_RIGHT = "\ue0b0"  #
PL_RIGHT_THIN = "\ue0b1"  #
PL_LEFT_ROUND = "\ue0b6"  #

# ANSI helpers
def fg(color_code):
    return f"\033[38;5;{color_code}m"

def bg(color_code):
    return f"\033[48;5;{color_code}m"

RESET = "\033[0m"
BOLD = "\033[1m"


def powerline_segments(segments):
    """Build a powerline string from a list of (bg_color, fg_color, text) tuples."""
    result = []
    for i, (bg_col, fg_col, text) in enumerate(segments):
        # Arrow separator from previous segment's bg to this segment's bg
        if i == 0:
            # Rounded left cap on first segment
            result.append(f"{fg(bg_col)}{PL_LEFT_ROUND}")
        else:
            prev_bg = segments[i - 1][0]
            result.append(f"{fg(prev_bg)}{bg(bg_col)}{PL_RIGHT}")
        if text:
            result.append(f"{bg(bg_col)}{fg(fg_col)} {text} ")
        else:
            result.append(f"{bg(bg_col)}")

    # Final arrow: last segment bg -> default background
    if segments:
        last_bg = segments[-1][0]
        result.append(f"{RESET}{fg(last_bg)}{PL_RIGHT}{RESET}")

    return "".join(result)


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
            return [s for s in sessions if s]
        return []
    except:
        return []


def get_port_from_tmux_session(session_name):
    """Extract port number from tmux session output."""
    try:
        import subprocess
        import re

        result = subprocess.run(
            ["tmux", "capture-pane", "-t", session_name, "-p", "-S", "-"],
            capture_output=True,
            text=True
        )

        if result.returncode != 0:
            return None

        output = result.stdout

        patterns = [
            r'Local:\s+https?://localhost:(\d+)',
            r'ready on port (\d+)',
            r'localhost:(\d+)',
            r'listening on.*:(\d+)',
            r'server running at.*:(\d+)',
            r'http://127\.0\.0\.1:(\d+)',
        ]

        for pattern in patterns:
            match = re.search(pattern, output, re.IGNORECASE)
            if match:
                return match.group(1)

        return None
    except:
        return None


_session_port_cache = {}


def get_server_status():
    """Get server status text for the tmux segment."""
    global _session_port_cache

    sessions = get_tmux_sessions()
    project = get_project_name()
    server_session_name = f"{project}-server"

    project_sessions = [s for s in sessions if s.startswith(f"{project}-")]

    if not project_sessions:
        _session_port_cache.clear()
        return None, False

    has_server = server_session_name in project_sessions
    other_sessions = [s for s in project_sessions if s != server_session_name]

    _session_port_cache = {k: v for k, v in _session_port_cache.items() if k in sessions}

    parts = []

    if has_server:
        if server_session_name not in _session_port_cache:
            port = get_port_from_tmux_session(server_session_name)
            if port:
                _session_port_cache[server_session_name] = port

        if server_session_name in _session_port_cache:
            port = _session_port_cache[server_session_name]
            parts.append(f":{port}")
        else:
            parts.append("up")
    else:
        _session_port_cache.pop(server_session_name, None)

    if len(other_sessions) == 1:
        session_name = other_sessions[0]
        suffix = session_name.removeprefix(f"{project}-")
        parts.append(suffix)
    elif len(other_sessions) > 1:
        parts.append(f"+{len(other_sessions)}")

    if not parts and not has_server:
        return None, False

    return " ".join(parts) if parts else "up", has_server


def generate_status_line(input_data):
    """Generate a powerline-styled status line."""
    segments = []

    # --- Model ---
    model_info = input_data.get("model") or {}
    model_name = model_info.get("display_name", "Claude")
    segments.append((133, 255, model_name))  # purple bg (#9A348E)

    # --- Project name ---
    project = get_project_name()
    segments.append((168, 255, project))  # pink/rose bg (#DA627D)

    # --- Git branch ---
    branch = get_git_branch()
    if branch is None:
        segments.append((240, 250, "no git"))
    elif branch in ["main", "master"]:
        segments.append((216, 255, f"\ue0a0 {branch}"))  # peach bg (#FCA17D)
    else:
        segments.append((216, 255, f"\ue0a0 {branch}"))  # peach bg (#FCA17D)

    # --- Context usage ---
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

        # Extra padding = number of 10% thresholds crossed
        extra = used_pct // 10
        label = f"{used_pct}%"
        label_len = len(label)
        total_width = label_len + extra
        left_pad = extra // 2
        right_pad = extra - left_pad

        if used_pct >= 75:
            ctx_bg = 9  # red
        elif used_pct >= 50:
            ctx_bg = 11  # yellow
        else:
            ctx_bg = 35   # green

        segments.append((ctx_bg, 255, f"{' ' * left_pad}{label}{' ' * right_pad}"))

    # --- Cost + Duration ---
    cost_info = input_data.get("cost") or {}
    total_cost = cost_info.get("total_cost_usd", 0)
    duration_ms = cost_info.get("total_duration_ms", 0)
    cost_parts = []
    if duration_ms > 0:
        total_mins = int(duration_ms / 60000)
        hours, mins = divmod(total_mins, 60)
        cost_parts.append(f"{hours}:{mins:02d}")
    if total_cost > 0:
        cost_parts.append(f" ${total_cost:.2f}")
    if cost_parts:
        segments.append((110, 255, f" \uefca ".join(cost_parts)))  # light blue bg (#86BBD8)
    else:
        segments.append((110, None, ""))  # empty sliver

    # --- Time ---
    ct = datetime.now(ZoneInfo("America/Chicago"))
    now = f"\uf017  {ct.strftime('%-m/%-d')} {ct.strftime('%-I:%M%p').lower()}"
    segments.append((30, 255, now))  # teal bg (#06969A)

    # --- Server/tmux status ---
    server_text, is_up = get_server_status()
    if server_text is not None:
        if is_up:
            segments.append((31, 255, f"\u25cf {server_text}"))  # dark blue bg (#33658A)
        else:
            segments.append((31, 255, server_text))  # dark blue bg (#33658A)
    else:
        segments.append((31, None, ""))  # empty sliver

    return powerline_segments(segments)


def main():
    try:
        input_data = json.loads(sys.stdin.read())
        status_line = generate_status_line(input_data)
        print(status_line)
        sys.exit(0)
    except Exception as e:
        print(f"\033[31mStatus line error: {str(e)}\033[0m")
        sys.exit(0)


if __name__ == "__main__":
    main()
