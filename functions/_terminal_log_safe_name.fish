# Copyright (C) 2026 Rootiest
# SPDX-License-Identifier: AGPL-3.0-or-later

# SYNOPSIS
#   _terminal_log_safe_name <name>
#
# DESCRIPTION
#   Prints <name> reduced to a safe file-name component: every character
#   outside [A-Za-z0-9._-] becomes "_". An empty result prints "unknown".
#   Used by the C5 log writers (_tmux_pipe_log, _zellij_dump_log) so that
#   multiplexer session names, which may contain spaces and shell
#   metacharacters, can never split or inject into a command line, and never
#   contain glob characters that would confuse _prune_terminal_logs.
#
# ARGUMENTS
#   name  The raw session or pane identifier
#
# EXIT STATUS
#   0  Always
#
# EXAMPLE
#   _terminal_log_safe_name 'my work;$(x)'    # my_work___x_
function _terminal_log_safe_name --description 'Reduce a string to a safe log file-name component'
    set -l safe (string replace -ar -- '[^A-Za-z0-9._-]' _ "$argv[1]")
    test -n "$safe"; or set safe unknown
    echo $safe
    return 0
end
