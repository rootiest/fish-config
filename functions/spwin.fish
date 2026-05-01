# Copyright (C) 2026 Rootiest
# SPDX-License-Identifier: AGPL-3.0-or-later

# spawn window in kitty or wezterm
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
