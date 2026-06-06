# Copyright (C) 2026 Rootiest
# SPDX-License-Identifier: AGPL-3.0-or-later

# SYNOPSIS
#   antigravity-resume
#
# DESCRIPTION
#   Resumes an Antigravity (agy) AI session using the session ID saved in
#   .antigravity_session in the current directory. Falls back to the interactive
#   session browser if no local session file exists.
#
# RETURNS
#   0  Session resumed or interactive picker opened
#   1  Required binaries (agy or save_antigravity_session) are not found
#
# EXAMPLE
#   antigravity-resume
function antigravity-resume --description 'Execute antigravity-resume'
    if not type -q agy
        echo "Error: The 'agy' command is not installed or not in PATH." >&2
        return 1
    end
    if not type -q save_antigravity_session
        echo "Error: The companion function 'save_antigravity_session' is missing." >&2
        return 1
    end

    if test -f .antigravity_session
        set -l sid (cat .antigravity_session)
        # Use --resume (or -r) to jump back in
        agy --resume $sid
    else
        # Fallback to the interactive session browser
        agy --resume
    end
end
