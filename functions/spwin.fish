# Copyright (C) 2026 Rootiest
# SPDX-License-Identifier: AGPL-3.0-or-later

# SYNOPSIS
#   spwin [args...]
#
# DESCRIPTION
#   Spawns a new terminal OS window in Kitty (via spawn-window.sh if
#   present, otherwise kitty @ launch) or WezTerm (via wezterm cli spawn).
#
# ARGUMENTS
#   args...  Arguments forwarded to the spawn command
#
# RETURNS
#   0  Window opened successfully
#   1  Not running inside Kitty or WezTerm
#
# EXAMPLE
#   spwin
function spwin --wraps='~/.config/kitty/spawn-window.sh' --description 'spawn window in kitty or wezterm'
    if test "$TERM" = xterm-kitty
        if test -x ~/.config/kitty/spawn-window.sh
            ~/.config/kitty/spawn-window.sh $argv
        else
            kitty @ launch --type=window $argv
        end
    else if test "$TERM_PROGRAM" = WezTerm
        wezterm cli spawn $argv
    else
        echo "Error: The 'spwin' command requires Kitty or WezTerm." >&2
        return 1
    end
end
