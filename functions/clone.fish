# Copyright (C) 2026 Rootiest
# SPDX-License-Identifier: AGPL-3.0-or-later

function clone --wraps=clone-in-kitty --description 'alias clone=clone-in-kitty'
    if test "$TERM" != xterm-kitty
        echo "Error: The 'clone' command requires Kitty terminal." >&2
        return 1
    end
    clone-in-kitty $argv
end
