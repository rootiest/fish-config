# Copyright (C) 2026 Rootiest
# SPDX-License-Identifier: AGPL-3.0-or-later

# Execute code-resume
function code-resume --description 'Execute code-resume'
    if test -f .claude_session
        set -l sid (cat .claude_session)
        echo "Resuming Claude session: $sid"
        claude --resume $sid
    else if test -f .antigravity_session
        set -l sid (cat .antigravity_session)
        echo "Resuming antigravity-cli session: $sid"
        agy --resume $sid
    else
        echo "No local AI session found. Opening picker..."
        claude --resume # Default to Claude picker
    end
end
