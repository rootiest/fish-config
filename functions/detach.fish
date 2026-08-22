# Copyright (C) 2026 Rootiest
# SPDX-License-Identifier: AGPL-3.0-or-later

# CATEGORY
#   08-terminal-management
#
# SYNOPSIS
#   detach [-h] [--version] <command> [args...]
#
# DESCRIPTION
#   Runs a command in the background using nohup, fully detached from the
#   terminal with stdout/stderr discarded. The command survives the current
#   session.
#
# ARGUMENTS
#   -h, --help   Show help message
#   --version    Show version information
#   command      The command to run detached
#   args...      Additional arguments for the command
#
# EXIT STATUS
#   0  Command launched or help/version shown
#   1  No command provided or unknown option
#
# EXAMPLE
#   detach rsync -a ./data remote:/backup/
function detach --description 'Execute detach'
    set -l c_head (set_color --bold cyan)
    set -l c_cmd (set_color --bold)
    set -l c_flag (set_color yellow)
    set -l c_arg (set_color cyan)
    set -l c_reset (set_color normal)

    set -l show_help 0
    set -l args

    for arg in $argv
        switch $arg
            case -h --help
                set show_help 1
            case --version
                echo "detach 1.0.0"
                return
            case '-*' '--*'
                echo "❌ Unknown option: $arg"
                echo "Run 'detach --help' for usage."
                return 1
            case '*'
                set args $args $arg
        end
    end

    if test $show_help -eq 1
        echo "$c_head""Usage:$c_reset $c_cmd""detach$c_reset $c_arg""[command...]$c_reset"
        echo "  Runs a command in the background, fully detached from the terminal."
        echo
        echo "$c_head""Options:$c_reset"
        echo "  $c_flag-h$c_reset, $c_flag--help$c_reset        Show this help message"
        echo "  $c_flag--version$c_reset         Show version information"
        echo
        echo "$c_head""Example:$c_reset"
        echo "  $c_cmd""detach$c_reset firefox"
        echo "  $c_cmd""detach$c_reset rsync -a ./data remote:/backup/"
        return
    end

    if test (count $args) -eq 0
        echo "❌ No command provided."
        echo "Run 'detach --help' for usage."
        return 1
    end

    nohup $args >/dev/null 2>&1 &
end
