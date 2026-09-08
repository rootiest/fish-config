# Copyright (C) 2026 Rootiest
# SPDX-License-Identifier: AGPL-3.0-or-later

# SYNOPSIS
#   __config_settings_diff_redraw <old_joined> <new_joined>
#
# DESCRIPTION
#   Rewrites an on-screen panel frame in place, touching only the lines
#   that changed. Assumes the cursor is already positioned at the top-left
#   of the frame (the caller moves it there with a plain \e[<n>A -- no
#   \e[J -- before calling this). Line count in old_joined and new_joined
#   must be equal; a caller facing a height or width change should use the
#   existing full erase+redraw path instead of calling this.
#
#   Unchanged lines advance the cursor with a bare newline, leaving
#   whatever is already on screen untouched. Changed lines clear just that
#   line (\e[2K), return to its start (\r), print the new content, and
#   advance (\n). This is what removes the erase-then-redraw flicker: the
#   screen is never blanked, only the handful of lines that actually
#   differ are ever touched, and each of those is cleared and rewritten in
#   the same breath rather than blanked-then-paused-then-filled.
#
# ARGUMENTS
#   old_joined  Previous frame, lines joined with \n
#   new_joined  New frame, lines joined with \n (same line count as old)
#
# EXIT STATUS
#   0  Always
#
# RETURNS
#   The ANSI sequence needed to turn the old frame into the new one,
#   printed to stdout
#
# EXAMPLE
#   __config_settings_diff_redraw (string join \n -- $prev_frame) \
#       (string join \n -- $new_frame)
function __config_settings_diff_redraw
    set -l old (string split \n -- $argv[1])
    set -l new (string split \n -- $argv[2])
    for i in (seq (count $new))
        if test "$old[$i]" = "$new[$i]"
            printf '\n'
        else
            printf '\e[2K\r%s\n' $new[$i]
        end
    end
end
