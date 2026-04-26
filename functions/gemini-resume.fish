# Copyright (C) 2026 Rootiest
# SPDX-License-Identifier: AGPL-3.0-or-later

function gemini-resume
    if test -f .gemini_session
        set -l sid (cat .gemini_session)
        # Use --resume (or -r) to jump back in
        gemini --resume $sid
    else
        # Fallback to the interactive session browser
        gemini --resume
    end
end
