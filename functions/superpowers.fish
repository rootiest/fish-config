# Copyright (C) 2026 Rootiest
# SPDX-License-Identifier: AGPL-3.0-or-later

# CATEGORY
#   12-ai-and-developer-tools
#
# DEPENDENCIES
#   agy
#
# CLASSIFICATION
#   uses-shadow(claude)
#
# SYNOPSIS
#   superpowers [on|off|help] [-g]
#
# DESCRIPTION
#   Enables or disables the superpowers plugin for both antigravity-cli
#   (workspace scope) and Claude (project scope). Use -g/--global to apply
#   at the user scope instead of workspace/project.
#
# ARGUMENTS
#   on            Enable superpowers for both tools
#   off           Disable superpowers for both tools
#   -g, --global  Apply at user/global scope instead of workspace/project
#   help, -h, --help  Show usage help
#
# EXIT STATUS
#   0  Mode applied successfully, or help was shown
#   2  Unknown command or option, or more than one command
#
# EXAMPLE
#   superpowers on
#   superpowers off -g
function superpowers --description 'Toggle superpowers extension for antigravity-cli and Claude'
    __fish_palette
    set -l scope_agy workspace
    set -l scope_claude project
    set -l mode ""
    set -l help_text "
Usage: superpowers [on|off] [options]

Commands:
  on       Enable superpowers for antigravity-cli and Claude
  off      Disable superpowers for antigravity-cli and Claude

Options:
  -g, --global    Apply settings to the user/global scope
  help, -h, --help  Show this help message
"

    # Checked before parsing so `superpowers on --help` changes nothing.
    if test "$argv[1]" = help; or __fish_help_requested $argv
        echo $help_text
        return 0
    end

    set -l cmd
    while set -q argv[1]
        set -l arg $argv[1]
        set -e argv[1]
        switch $arg
            case --
                # Ends option parsing: what follows is data, never a flag.
                set -a cmd $argv
                break
            case -g --global
                set scope_agy user
                set scope_claude user
            case '-*'
                echo "$c_err""superpowers: unknown option '$arg'$c_reset" >&2
                echo "Run $c_cmd""superpowers help$c_reset for usage." >&2
                return 2
            case '*'
                set -a cmd $arg
        end
    end

    # Bare invocation is how a command is discovered: help, not an error.
    if not set -q cmd[1]
        echo $help_text
        return 0
    end
    if set -q cmd[2]
        echo "$c_err""superpowers: expected one command, got '$cmd'$c_reset" >&2
        echo "Run $c_cmd""superpowers help$c_reset for usage." >&2
        return 2
    end
    switch $cmd
        case on
            set mode enable
        case off
            set mode disable
        case '*'
            echo "$c_err""superpowers: unknown command '$cmd'$c_reset" >&2
            echo "Run $c_cmd""superpowers help$c_reset for usage." >&2
            return 2
    end

    echo "Setting superpowers to: $mode (Scope: antigravity-cli=$scope_agy, Claude=$scope_claude)..."

    # Execute antigravity-cli command
    agy extensions $mode superpowers --scope $scope_agy

    # Execute Claude command
    claude plugins $mode superpowers --scope $scope_claude
end
