# Copyright (C) 2026 Rootiest
# SPDX-License-Identifier: AGPL-3.0-or-later

function code-resume
    if test -f .claude_session
        set -l sid (cat .claude_session)
        echo "Resuming Claude session: $sid"
        claude --resume $sid
    else if test -f .gemini_session
        set -l sid (cat .gemini_session)
        echo "Resuming Gemini session: $sid"
        gemini --resume $sid
    else
        echo "No local AI session found. Opening picker..."
        claude --resume # Default to Claude picker
    end
end
