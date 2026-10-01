# Copyright (C) 2026 Rootiest
# SPDX-License-Identifier: AGPL-3.0-or-later

# CATEGORY
#   14-miscellaneous
#
# DEPENDENCIES
#   ffetch
#
# SYNOPSIS
#   cffetch [args...]
#
# DESCRIPTION
#   Clears the screen, then runs ffetch (fastfetch with a custom config if
#   available, falling back to neofetch).
#
# ARGUMENTS
#   args...  Additional arguments forwarded to ffetch
#
# EXAMPLE
#   cffetch
function cffetch --wraps=ffetch --description 'Clear the screen, then ffetch'
    clear
    ffetch $argv
end
