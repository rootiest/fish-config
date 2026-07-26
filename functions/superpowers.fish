# Copyright (C) 2026 Rootiest
# SPDX-License-Identifier: AGPL-3.0-or-later

# CATEGORY
#   12-ai-and-developer-tools
#
# SYNOPSIS
#   superpowers [on|off] [-g]
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
#   -h, --help    Show usage help
#
# RETURNS
#   0  Mode applied successfully
#   1  No on/off mode specified
#
# EXAMPLE
#   superpowers on
#   superpowers off -g
function superpowers --description 'Toggle superpowers extension for antigravity-cli and Claude'
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
  -h, --help      Show this help message
"

    # Parse arguments
    for arg in $argv
        switch $arg
            case on
                set mode enable
            case off
                set mode disable
            case -g --global
                set scope_agy user
                set scope_claude user
            case -h --help
                echo $help_text
                return 0
        end
    end

    # Handle no arguments or invalid mode
    if test -z "$mode"
        echo $help_text
        return 1
    end

    echo "Setting superpowers to: $mode (Scope: antigravity-cli=$scope_agy, Claude=$scope_claude)..."

    # Execute antigravity-cli command
    agy extensions $mode superpowers --scope $scope_agy

    # Execute Claude command
    claude plugins $mode superpowers --scope $scope_claude
end
