# Copyright (C) 2026 Rootiest
# SPDX-License-Identifier: AGPL-3.0-or-later

# SYNOPSIS
#   mkdir [args...]
#
# DESCRIPTION
#   Interactive wrapper around mkdir that calls _fish_mkdir_p for each
#   directory argument to display created path components. Falls back to
#   command mkdir -p when flags (e.g. -m 755) are present, and to plain
#   command mkdir in non-interactive contexts.
#
# ARGUMENTS
#   args...  Directories to create, or flags passed through to command mkdir
#
# EXAMPLE
#   mkdir ~/projects/myapp/src
function mkdir --description 'Execute mkdir'
    # Opinionated guard (C1): fall back to bare command mkdir when disabled.
    if not __fish_config_op_enabled __fish_config_op_aliases
        command mkdir $argv
        return $status
    end

    if status is-interactive
        # Fall back to command mkdir -p when flags are present (e.g. -m 755)
        for _arg in $argv
            if string match -q -- '-*' $_arg
                command mkdir -p $argv
                return $status
            end
        end
        for _dir in $argv
            _fish_mkdir_p --path $_dir
        end
    else
        command mkdir $argv
    end
end
