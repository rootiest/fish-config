# Copyright (C) 2026 Rootiest
# SPDX-License-Identifier: AGPL-3.0-or-later

# SYNOPSIS
#   ltr [args...]
#
# DESCRIPTION
#   Lists all files sorted by modification time in reverse (oldest first) in
#   long format with age-based gradient color scaling. Uses eza, falls back
#   to lsd, then to system ls.
#
# ARGUMENTS
#   args...  Arguments forwarded to the listing command
#
# EXAMPLE
#   ltr ~/projects
function ltr --description 'Reversed time-sorted listing'
    if which eza >/dev/null 2>&1
        eza --long --all --sort=modified --icons --hyperlink --color=auto --color-scale=age --color-scale-mode=gradient $argv
    else if which lsd >/dev/null 2>&1
        lsd --long --all --sort=time --reverse --color=auto --hyperlink=always $argv
    else
        command ls --color=auto -ltr $argv
    end
end
