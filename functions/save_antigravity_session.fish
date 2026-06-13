#!/usr/bin/env fish

# Copyright (C) 2026 Rootiest
# SPDX-License-Identifier: AGPL-3.0-or-later

# SYNOPSIS
#   Invoked as an Antigravity session hook; reads JSON from stdin.
#
# DESCRIPTION
#   Hook script called by the Antigravity CLI (agy) on session start.
#   Reads a JSON payload from stdin, extracts the session_id field, and
#   writes it to .antigravity_session in the current directory. Ensures
#   that file is excluded via .gitignore. Sets the universal variable
#   LAST_ANTIGRAVITY_SESSION for cross-terminal access. Falls back to a
#   no-op (emitting "{}") when python3 is unavailable (Convention §6).
#
# ARGUMENTS
#   stdin  JSON payload from the Antigravity CLI containing a "session_id" key
#
# RETURNS
#   0  Always; emits "{}" to stdout as required by the hook contract
#
# EXAMPLE
#   echo '{"session_id":"abc123"}' | fish save_antigravity_session.fish
#   cat .antigravity_session   # → abc123
#   echo $LAST_ANTIGRAVITY_SESSION   # → abc123

# 1. Read the JSON from stdin
set -l input (cat)

# 2. Extract session_id using Python
#    If python3 is unavailable, emit valid empty JSON and skip session
#    tracking rather than erroring (see AGENTS.md Convention §6).
if not type -q python3
    echo '{}'
    exit 0
end
set -l sid (echo $input | python3 -c "import sys,json; print(json.load(sys.stdin).get('session_id', ''))")
set -l session_file ".antigravity_session"

if test -n "$sid"
    # 3. Save the session ID locally
    echo "$sid" >$session_file

    # 4. Smart .gitignore check
    # We only attempt this if we are inside a Git repository
    if git rev-parse --is-inside-work-tree >/dev/null 2>&1
        # If 'git check-ignore' fails, it means the file is NOT currently ignored
        if not git check-ignore -q $session_file
            # Append a labeled entry to .gitignore
            echo -e "\n# AI Session IDs\n$session_file" >>.gitignore
        end
    end

    # 5. Update universal variable for cross-terminal access
    set -U LAST_ANTIGRAVITY_SESSION "$sid"
end

# MANDATORY: Every hook must output valid JSON or an empty object
echo '{}'
