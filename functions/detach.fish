# Copyright (C) 2026 Rootiest
# SPDX-License-Identifier: AGPL-3.0-or-later

# CATEGORY
#   08-terminal-management
#
# DEPENDENCIES
#   nohup
#
# SYNOPSIS
#   detach [-h] [--version] [--] <command> [args...]
#
# DESCRIPTION
#   Runs a command in the background using nohup, fully detached from the
#   terminal with stdout/stderr discarded. The command survives the current
#   session.
#
#   detach reads its own options only before the command. The first other
#   word is the command's name, and it and everything after it are passed
#   on unchanged, so options meant for the command (even -h or --version)
#   reach it. Use -- to run a command whose name starts with -.
#
# ARGUMENTS
#   -h, --help   Show help message
#   --version    Show version information
#   --           End detach's options
#   command      The command to run detached
#   args...      Additional arguments for the command
#
# EXIT STATUS
#   0  Command launched or help/version shown
#   1  nohup is not installed
#   2  No command provided, or an unknown option before the command
#
# EXAMPLE
#   detach rsync -a ./data remote:/backup/
#   detach ls -la
function detach --description 'Execute detach'
    __fish_palette

    # detach's own options come first. The first word that is not one of
    # them (or whatever follows --) is the command: it and everything after
    # it are forwarded untouched, so `detach ls -la` passes -la to ls.
    set -l show_help 0
    while set -q argv[1]
        switch $argv[1]
            case -h --help
                set show_help 1
            case --version
                echo "detach 1.0.0"
                return
            case --
                set -e argv[1]
                break
            case '-*'
                echo "$c_err""detach: unknown option '$argv[1]'$c_reset" >&2
                echo "Run $c_cmd""detach --help$c_reset for usage." >&2
                return 2
            case '*'
                break
        end
        set -e argv[1]
    end
    set -l args $argv

    if test $show_help -eq 1
        echo "$c_head""Usage:$c_reset $c_cmd""detach$c_reset $c_flag""[options] [--]$c_reset $c_arg""<command> [args...]$c_reset"
        echo "  Runs a command in the background, fully detached from the terminal."
        echo
        echo "$c_head""Options:$c_reset"
        echo "  $c_flag-h$c_reset, $c_flag--help$c_reset        Show this help message"
        echo "  $c_flag--version$c_reset         Show version information"
        echo "  $c_flag--$c_reset                End detach's options (for a command starting with -)"
        echo
        echo "  Options are read only before the command; everything from the"
        echo "  command's name on is passed to it unchanged."
        echo
        echo "$c_head""Example:$c_reset"
        echo "  $c_cmd""detach$c_reset firefox"
        echo "  $c_cmd""detach$c_reset rsync -a ./data remote:/backup/"
        return 0
    end

    if test (count $args) -eq 0
        echo "$c_err""detach: no command given$c_reset" >&2
        echo "Run $c_cmd""detach --help$c_reset for usage." >&2
        return 2
    end

    if not type -q nohup
        echo (__fish_color red)"Error: nohup is not installed."(__fish_color normal) >&2
        return 1
    end

    nohup $args >/dev/null 2>&1 &
end
