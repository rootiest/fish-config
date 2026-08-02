# Copyright (C) 2026 Rootiest
# SPDX-License-Identifier: AGPL-3.0-or-later

# CATEGORY
#   01-file-and-directory
#
# SYNOPSIS
#   lstree [args...]
#
# DESCRIPTION
#   Displays a full recursive tree of the current directory with icons.
#   Uses eza, falls back to lsd, then to system ls -R.
#
# ARGUMENTS
#   args...  Arguments forwarded to the listing command
#
# EXAMPLE
#   lstree ~/projects/myapp
function lstree --description 'Full recursive tree listing'
    if which eza >/dev/null 2>&1
        eza --tree --icons --color=auto --hyperlink=auto $argv
    else if which lsd >/dev/null 2>&1
        lsd --tree --hyperlink=auto $argv
    else
        command ls --color=auto -R $argv
    end
end
