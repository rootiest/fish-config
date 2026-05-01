# Copyright (C) 2026 Rootiest
# SPDX-License-Identifier: AGPL-3.0-or-later

# alias view=nvim -R
function view --wraps='nvim -R' --description 'alias view=nvim -R'
    if type -q nvim
        nvim -R $argv
    else if type -q less
        less $argv
    else
        command cat $argv
    end
        
end
