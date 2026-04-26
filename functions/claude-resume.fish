# Copyright (C) 2026 Rootiest
# SPDX-License-Identifier: AGPL-3.0-or-later

function claude-resume
    if test -f .claude_session
        set -l sid (cat .claude_session)
        claude --resume $sid
    else
        echo "No saved session found in this directory."
        claude --resume # Fallback to the interactive picker
    end
end
