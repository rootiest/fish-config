# Copyright (C) 2026 Rootiest
# SPDX-License-Identifier: AGPL-3.0-or-later

# CATEGORY
#   08-terminal-management
#
# SYNOPSIS
#   ssh [args...]
#
# DESCRIPTION
#   Wraps ssh with kitten ssh inside Kitty terminal for better terminal
#   integration (e.g. terminfo forwarding). Falls back to system ssh on
#   other terminals.
#
# ARGUMENTS
#   args...  Arguments forwarded to kitten ssh or system ssh
#
# EXAMPLE
#   ssh user@host
function ssh --description 'Alias ssh to kitten ssh when using Kitty terminal'
    # Opinionated guard (C1): fall back to bare command ssh when disabled.
    if not __fish_config_op_enabled __fish_config_op_aliases
        command ssh $argv
        return $status
    end

    if test "$TERM" = xterm-kitty
        kitten ssh $argv
    else
        command ssh $argv
    end
end
