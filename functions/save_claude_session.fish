#!/usr/bin/env fish

# Copyright (C) 2026 Rootiest
# SPDX-License-Identifier: AGPL-3.0-or-later

# 1. Read input and extract session ID
set -l input (cat)
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
