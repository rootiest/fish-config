# Copyright (C) 2026 Rootiest
# SPDX-License-Identifier: AGPL-3.0-or-later

# SYNOPSIS
#   _undo_backward_kill
#
# DESCRIPTION
#   Reverses the most recent deletion made through _backward_kill_remember,
#   restoring the deleted text and the cursor position. Repeated presses
#   reverse earlier deletions in turn. Does nothing unless the command line
#   is exactly as that deletion left it: once anything else is typed or
#   deleted, or a new command line starts, the saved deletions are dropped.
#   Intended to be bound to a key in key_bindings.fish.
#
# EXAMPLE
#   bind ctrl-shift-backspace _undo_backward_kill
function _undo_backward_kill --description 'Restore text deleted by the remembered backward-kill'
    if test "$__backward_kill_gen" != "$status_generation"
        set -g __backward_kill_buffers
        set -g __backward_kill_cursors
        return 0
    end

    set -l buf "$(commandline)"
    set -l cur (commandline -C)
    set -l len (string length -- "$buf")

    while set -q __backward_kill_buffers[1]
        set -l prev $__backward_kill_buffers[-1]
        set -l prev_cur $__backward_kill_cursors[-1]
        set -e __backward_kill_buffers[-1]
        set -e __backward_kill_cursors[-1]

        # A kill at the start of the line deleted nothing; skip it.
        set -l removed (math (string length -- "$prev") - $len)
        test $removed -eq 0; and continue

        # The current line must be the saved one minus the text right
        # before the saved cursor, with the cursor where the kill left it.
        if test $removed -gt 0
            and test $prev_cur -eq (math $cur + $removed)
            and test "$(string sub -l $cur -- "$prev")" = "$(string sub -l $cur -- "$buf")"
            and test "$(string sub -s (math $prev_cur + 1) -- "$prev")" = "$(string sub -s (math $cur + 1) -- "$buf")"
            commandline -- "$prev"
            commandline -C $prev_cur
            return 0
        end
        break
    end

    # Something else changed the line since; the saved deletions are stale.
    set -g __backward_kill_buffers
    set -g __backward_kill_cursors
    return 0
end
