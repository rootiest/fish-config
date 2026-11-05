# Copyright (C) 2026 Rootiest
# SPDX-License-Identifier: AGPL-3.0-or-later

# CATEGORY
#   01-file-and-directory
#
# COMPONENT
#   aliases/filesystem
#
# DEPENDENCIES
#   eza, lsd
#
# CLASSIFICATION
#   bypasses-shadow(ls)
#
# SYNOPSIS
#   ls [args...]
#
# DESCRIPTION
#   Lists all files in long format with icons and hyperlinks. With eza, also
#   shows a header row, octal permissions, Git status, extended attributes,
#   and line counts (eza 0.23.5+), with gradient size coloring. Falls back to
#   lsd, then to system ls.
#
# ARGUMENTS
#   args...  Arguments forwarded to the listing command
#
# EXAMPLE
#   ls ~/projects
#   ls
#   ls -a ~/projects
function ls --description 'List all files'
    # Opinionated guard (C1): fall back to bare command ls when disabled.
    if not __fish_config_op_enabled (status current-function)
        command ls $argv
        return $status
    end

    if which eza >/dev/null 2>&1
        # Probe once per session: eza before 0.23.5 has no --loc and rejects
        # a value on --hyperlink, and an unknown flag aborts the whole listing.
        if not set -q __ls_eza_flags
            set -g __ls_eza_flags
            if eza --hyperlink=auto -d / >/dev/null 2>&1
                set -a __ls_eza_flags --hyperlink=auto
            else
                set -a __ls_eza_flags --hyperlink
            end
            if eza --loc=lines -d / >/dev/null 2>&1
                set -a __ls_eza_flags --loc=lines
            end
        end
        eza --long --all --icons --color=auto --color-scale=all --color-scale-mode=gradient --git --extended --octal-permissions --header $__ls_eza_flags $argv

    else if which lsd >/dev/null 2>&1
        lsd -l -a --hyperlink=auto $argv
    else
        command ls --color=auto $argv
    end
end
