# Copyright (C) 2026 Rootiest
# SPDX-License-Identifier: AGPL-3.0-or-later

# SYNOPSIS
#   claude-resume
#
# DESCRIPTION
#   Resumes a Claude Code session using the ID saved in .claude_session in the
#   current directory. Falls back to the interactive session picker if no file
#   exists.
#
# RETURNS
#   0  Session resumed or interactive picker opened
#   1  Required binaries (claude or save_claude_session) are not found
#
# EXAMPLE
#   claude-resume
function claude-resume --description 'Execute claude-resume'
    if not type -q claude
        echo "Error: The 'claude' command is not installed or not in PATH." >&2
        return 1
    end
    if not type -q save_claude_session
        echo "Error: The companion function 'save_claude_session' is missing." >&2
        return 1
    end

    if test -f .claude_session
        set -l sid (cat .claude_session)
        claude --resume $sid
    else
        echo "No saved session found in this directory."
        claude --resume # Fallback to the interactive picker
    end
end
