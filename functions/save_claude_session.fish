#!/usr/bin/env fish

# Copyright (C) 2026 Rootiest
# SPDX-License-Identifier: AGPL-3.0-or-later

# SYNOPSIS
#   Invoked as a Claude Code session hook; reads JSON from stdin.
#
# DESCRIPTION
#   Hook script called by Claude Code on session start. Reads a JSON payload
#   from stdin, extracts the session_id field, and writes it to .claude_session
#   in the current directory. Ensures that file is excluded via .gitignore.
#   Sets the universal variable LAST_CLAUDE_SESSION for cross-terminal access.
#   Falls back to a no-op (emitting "{}") when python3 is unavailable
#   (Convention §6).
#
# ARGUMENTS
#   stdin  JSON payload from Claude Code containing a "session_id" key
#
# RETURNS
#   0  Always; emits "{}" to stdout as required by the hook contract
#
# EXAMPLE
#   echo '{"session_id":"abc123"}' | fish save_claude_session.fish
#   cat .claude_session   # → abc123
#   echo $LAST_CLAUDE_SESSION   # → abc123

# 1. Read input and extract session ID
#    python3 parses the session_id out of the hook's JSON payload. If it is
#    unavailable we emit valid empty JSON and skip session tracking rather
#    than erroring (see AGENTS.md Convention §6).
set -l input (cat)
if not type -q python3
    echo '{}'
    exit 0
end
set -l sid (echo $input | python3 -c "import sys,json; print(json.load(sys.stdin).get('session_id', ''))")
set -l session_file ".claude_session"

if test -n "$sid"
    # 2. Save the session ID locally
    echo "$sid" >$session_file

    # 3. Smart .gitignore check
    # We check if git even knows about this file. 
    # If 'git check-ignore' returns 1, it means the file is NOT ignored.
    if git rev-parse --is-inside-work-tree >/dev/null 2>&1
        if not git check-ignore -q $session_file
            # Append the filename to .gitignore
            echo -e "\n# AI Session IDs\n$session_file" >>.gitignore
            echo "Added $session_file to .gitignore"
        end
    end

    # 4. Update universal variable
    set -U LAST_CLAUDE_SESSION "$sid"
end

# MANDATORY: Every hook must output valid JSON
echo '{}'
