# Copyright (C) 2026 Rootiest
# SPDX-License-Identifier: AGPL-3.0-or-later

# SYNOPSIS
#   cheat <topic> [args...]
#
# DESCRIPTION
#   Displays colorized cheatsheets using cheat -c. Falls back to tldr, then
#   man, if cheat is not installed.
#
# ARGUMENTS
#   topic   The command or topic to look up
#   args... Additional arguments forwarded to cheat, tldr, or man
#
# EXAMPLE
#   cheat tar
function cheat --wraps='cheat' --description 'alias cheat=cheat -c'
    if type -q cheat
        command cheat -c $argv
    else if type -q tldr
        tldr $argv
    else
        man $argv
    end
        
end
