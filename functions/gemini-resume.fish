# Copyright (C) 2026 Rootiest
# SPDX-License-Identifier: AGPL-3.0-or-later

# Execute gemini-resume
function gemini-resume --description 'Execute gemini-resume'
    if not type -q gemini-cli
        echo "Error: The 'gemini-cli' command is not installed or not in PATH." >&2
        return 1
    end
    if not type -q save_gemini_session
        echo "Error: The companion function 'save_gemini_session' is missing." >&2
        return 1
    end

    if test -f .gemini_session
        set -l sid (cat .gemini_session)
        # Use --resume (or -r) to jump back in
        gemini --resume $sid
    else
        # Fallback to the interactive session browser
        gemini --resume
    end
end
