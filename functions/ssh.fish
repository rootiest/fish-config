# Copyright (C) 2026 Rootiest
# SPDX-License-Identifier: AGPL-3.0-or-later

# Alias ssh to kitten ssh when using Kitty terminal
function ssh --description 'Alias ssh to kitten ssh when using Kitty terminal'
    if test "$TERM" = xterm-kitty
        kitten ssh $argv
    else
        command ssh $argv
    end
end
