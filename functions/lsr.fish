# Copyright (C) 2026 Rootiest
# SPDX-License-Identifier: AGPL-3.0-or-later

# CATEGORY
#   01-file-and-directory
#
# SYNOPSIS
#   lsr [args...]
#
# DESCRIPTION
#   Lists files sorted by modification time in reverse (oldest first), one
#   per line with icons. Uses eza, falls back to lsd, then to system ls.
#
# ARGUMENTS
#   args...  Arguments forwarded to the listing command
#
# EXAMPLE
#   lsr ~/projects
function lsr --description 'Reversed time-sorted listing'
    if which eza >/dev/null 2>&1
        eza --oneline --sort=modified --reverse --icons --color=auto --hyperlink $argv
    else if which lsd >/dev/null 2>&1
        lsd -ltr $argv
    else
        command ls --color=auto -ltr $argv
    end
end
