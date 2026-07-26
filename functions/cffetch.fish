# Copyright (C) 2026 Rootiest
# SPDX-License-Identifier: AGPL-3.0-or-later

# CATEGORY
#   14-miscellaneous
#
# SYNOPSIS
#   cffetch [args...]
#
# DESCRIPTION
#   Clears the screen and displays system information using fastfetch with a
#   custom config if available. Falls back to neofetch if fastfetch is not installed.
#
# ARGUMENTS
#   args...  Additional arguments forwarded to fastfetch or neofetch
#
# EXAMPLE
#   cffetch
function cffetch --description 'alias cffetch=clear;fastfetch'
    clear
    if which fastfetch >/dev/null 2>&1
        if ls ~/.fastfetch.jsonc >/dev/null 2>&1
            fastfetch --config ~/.fastfetch.jsonc $argv
        else
            fastfetch $argv
        end
    else
        if which neofetch >/dev/null 2>&1
            command neofetch $argv
        else
            echo "fetch not found"
        end
    end
end
