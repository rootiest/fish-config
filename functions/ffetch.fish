# Copyright (C) 2026 Rootiest
# SPDX-License-Identifier: AGPL-3.0-or-later

# CATEGORY
#   14-miscellaneous
#
# SYNOPSIS
#   ffetch [args...]
#
# DESCRIPTION
#   Alias for fastfetch that loads a custom config from ~/.fastfetch.jsonc when
#   present. Falls back to neofetch if fastfetch is not installed.
#
# ARGUMENTS
#   args...  Arguments forwarded to fastfetch or neofetch
#
# EXAMPLE
#   ffetch
function ffetch --wraps='fastfetch' --description 'alias ffetch=fastfetch'
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
