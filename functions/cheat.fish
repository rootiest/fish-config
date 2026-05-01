# Copyright (C) 2026 Rootiest
# SPDX-License-Identifier: AGPL-3.0-or-later

# alias cheat=cheat -c
function cheat --wraps='cheat' --description 'alias cheat=cheat -c'
    if type -q cheat
        command cheat -c $argv
    else if type -q tldr
        tldr $argv
    else
        man $argv
    end
        
end
