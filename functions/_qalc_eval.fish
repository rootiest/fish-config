# Copyright (C) 2026 Rootiest
# SPDX-License-Identifier: AGPL-3.0-or-later

# SYNOPSIS
#   _qalc_eval
#
# DESCRIPTION
#   Reads the current commandline buffer and evaluates it as a qalc
#   expression, printing the result. Clears the buffer and repaints
#   after evaluation. No-ops if qalc is not installed or the buffer
#   is empty. Intended to be bound to a key in key_bindings.fish.
#
# RETURNS
#   1  qalc not found in PATH
#
# EXAMPLE
#   bind \cr _qalc_eval
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
