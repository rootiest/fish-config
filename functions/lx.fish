# Copyright (C) 2026 Rootiest
# SPDX-License-Identifier: AGPL-3.0-or-later

# SYNOPSIS
#   lx [args...]
#
# DESCRIPTION
#   Lists all files sorted by file extension in long format with icons. Uses
#   eza, falls back to lsd, then to system ls -lX.
#
# ARGUMENTS
#   args...  Arguments forwarded to the listing command
#
# EXAMPLE
#   lx ~/projects
function lx --description 'Extension-sorted listing'
    if which eza >/dev/null 2>&1
        eza --long --all --sort=extension --icons --color=auto --hyperlink $argv
    else if which lsd >/dev/null 2>&1
        lsd --long --all --sort=extension --hyperlink=auto $argv
    else
        command ls --color=auto -lX $argv
    end
end
