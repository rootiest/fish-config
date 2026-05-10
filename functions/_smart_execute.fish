# Copyright (C) 2026 Rootiest
# SPDX-License-Identifier: AGPL-3.0-or-later

# Executes different functions based on the command line content
function _smart_execute --description 'Execute different functions based on the command line content'
    # Get the current command line buffer
    set -l cmd (commandline)

    # 1. Handle empty buffer (Standard Enter behavior)
    if test -z "$cmd"
        commandline -f execute
        return
    end

    # 2. Dispatch based on buffer content
    switch "$cmd"
        case '*='
            # If it ends in =, run qalc
            _qalc_eval

#       case 'g *'
#           # EXAMPLE FUTURE EXTENSION
#           _some_git_helper

        case '*'
            # Default: execute the command line as-is
            commandline -f execute
    end
end
