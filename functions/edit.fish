# Copyright (C) 2026 Rootiest
# SPDX-License-Identifier: AGPL-3.0-or-later

# alias edit=nvim
function edit --wraps='nvim' --description 'alias edit=nvim'
    if type -q nvim
        nvim $argv
    else if set -q EDITOR
        $EDITOR $argv
    else if type -q nano
        nano $argv
    else
        vi $argv
    end
end
