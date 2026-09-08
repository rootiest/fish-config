# Copyright (C) 2026 Rootiest
# SPDX-License-Identifier: AGPL-3.0-or-later

# CATEGORY
#   01-file-and-directory
#
# SYNOPSIS
#   lD [args...]
#
# DESCRIPTION
#   Lists only directories in long format with icons and hyperlinks. Uses eza,
#   falls back to lsd, then to system ls.
#
# ARGUMENTS
#   args...  Arguments forwarded to the listing command
#
# EXIT STATUS
#   Exit status of eza, lsd, or ls, whichever ran
#
# EXAMPLE
#   lD ~/projects
function lD --description 'List directories only'
    __fish_help_header (status current-function) $argv; and return 0

    if which eza >/dev/null 2>&1
        eza --only-dirs --long --icons --color=auto --hyperlink $argv
    else if which lsd >/dev/null 2>&1
        lsd --only-dirs --long --hyperlink=auto $argv
    else
        command ls --color=auto -d -- */ $argv
    end
end
