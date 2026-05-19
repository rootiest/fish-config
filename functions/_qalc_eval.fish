# Copyright (C) 2026 Rootiest
# SPDX-License-Identifier: AGPL-3.0-or-later

# Returns the result of a qalc calculation
function _qalc_eval
    type -q qalc || return 1

    # Get the current command line buffer
    set -l cmd (commandline)

    # If the buffer isn't empty, run it through qalc
    if test -n "$cmd"
        echo
        # Passes the buffer to qalc
        # -t (terse) is optional, remove it if you want the full verbose output
        echo "$cmd" | qalc

        # Clear the command line for the next task
        commandline -r ""
        commandline -f repaint
    end
end
