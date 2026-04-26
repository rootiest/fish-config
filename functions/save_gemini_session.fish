# Copyright (C) 2026 Rootiest
# SPDX-License-Identifier: AGPL-3.0-or-later

#!/usr/bin/env fish

# 1. Read the JSON from stdin
set -l input (cat)

# 2. Extract session_id using Python
set -l sid (echo $input | python3 -c "import sys,json; print(json.load(sys.stdin).get('session_id', ''))")
set -l session_file ".gemini_session"

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
    set -U LAST_GEMINI_SESSION "$sid"
end

# MANDATORY: Every hook must output valid JSON or an empty object
echo '{}'
