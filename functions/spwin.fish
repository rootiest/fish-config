# Copyright (C) 2026 Rootiest
# SPDX-License-Identifier: AGPL-3.0-or-later

function spwin --wraps='~/.config/kitty/spawn-window.sh' --description 'alias spwin=~/.config/kitty/spawn-window.sh'
    if test "$TERM" != xterm-kitty
        echo "Error: The 'spwin' command requires Kitty terminal." >&2
        return 1
    end
    ~/.config/kitty/spawn-window.sh $argv
end
