# Copyright (C) 2026 Rootiest
# SPDX-License-Identifier: AGPL-3.0-or-later

# SYNOPSIS
#   _backward_kill_remember READLINE-FUNCTION
#
# DESCRIPTION
#   Saves the commandline buffer and cursor position, then runs the given
#   backward-kill readline function (e.g. backward-kill-token). The saved
#   states form a stack that _undo_backward_kill pops to reverse each
#   deletion in turn. The deleted text still goes to the kill ring, so
#   Ctrl+Y yanks it as usual. Intended to be bound to a key in
#   key_bindings.fish.
#
# EXAMPLE
#   bind ctrl-backspace '_backward_kill_remember backward-kill-token'
function _backward_kill_remember --description 'Run a backward-kill and remember the text it deletes'
    # A stack left over from an earlier command line is stale.
    if test "$__backward_kill_gen" != "$status_generation"
        set -g __backward_kill_buffers
        set -g __backward_kill_cursors
        set -g __backward_kill_gen $status_generation
    end
    set -ga __backward_kill_buffers "$(commandline)"
    set -ga __backward_kill_cursors (commandline -C)
    commandline -f $argv[1]
end
