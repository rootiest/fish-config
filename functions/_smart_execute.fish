# Copyright (C) 2026 Rootiest
# SPDX-License-Identifier: AGPL-3.0-or-later

# SYNOPSIS
#   _smart_execute
#
# DESCRIPTION
#   Bound to Enter, dispatches based on the current commandline buffer.
#   Buffers ending in = are evaluated as qalc expressions via _qalc_eval.
#   Empty buffers and all other input fall through to normal execution.
#   Intended to be bound to a key in key_bindings.fish.
#
# EXAMPLE
#   bind \r _smart_execute
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
            # If it ends in =, run qalc; fall back to normal execute if qalc is absent
            _qalc_eval; or commandline -f execute

#       case 'g *'
#           # EXAMPLE FUTURE EXTENSION
#           _some_git_helper

        case '*'
            # Default: execute the command line as-is
            commandline -f execute
    end
end
