# Copyright (C) 2026 Rootiest
# SPDX-License-Identifier: AGPL-3.0-or-later

# SYNOPSIS
#   lss [args...]
#
# DESCRIPTION
#   Lists all files sorted by size in long format with gradient color scaling.
#   Uses eza, falls back to lsd, then to system ls.
#
# ARGUMENTS
#   args...  Arguments forwarded to the listing command
#
# EXAMPLE
#   lss ~/downloads
function lss --description 'Size-sorted listing'
    if which eza >/dev/null 2>&1
        eza --oneline --long --all --sort=size --icons --color=auto --hyperlink --color-scale=size --color-scale-mode=gradient $argv
    else if which lsd >/dev/null 2>&1
        lsd --oneline --long --all --sort=size --reverse --color=auto --hyperlink=always $argv
    else
        command ls $argv
    end
end
