# Copyright (C) 2026 Rootiest
# SPDX-License-Identifier: AGPL-3.0-or-later

# SYNOPSIS
#   ls [args...]
#
# DESCRIPTION
#   Lists all files in long format with icons and hyperlinks. Uses eza,
#   falls back to lsd, then to system ls.
#
# ARGUMENTS
#   args...  Arguments forwarded to the listing command
#
# EXAMPLE
#   ls ~/projects
function ls --description 'List all files'
    # Opinionated guard (C1): fall back to bare command ls when disabled.
    if not __fish_config_op_enabled __fish_config_op_aliases
        command ls $argv
        return $status
    end

    if which eza >/dev/null 2>&1
        eza -l -a --icons --color=auto --hyperlink $argv

    else if which lsd >/dev/null 2>&1
        lsd -l -a --hyperlink=auto $argv
    else
        command ls --color=auto $argv
    end
end
