# Copyright (C) 2026 Rootiest
# SPDX-License-Identifier: AGPL-3.0-or-later

# alias clonet=clone-in-kitty --type=tab
function clonet --wraps='clone-in-kitty --type=tab' --description 'alias clonet=clone-in-kitty --type=tab'
    if test "$TERM" != xterm-kitty
        echo "Error: The 'clonet' command requires Kitty terminal." >&2
        return 1
    end
    clone-in-kitty --type=tab $argv
end
