# Copyright (C) 2026 Rootiest
# SPDX-License-Identifier: AGPL-3.0-or-later

# SYNOPSIS
#   ping [args...]
#
# DESCRIPTION
#   Wraps prettyping with --nolegend by default for a cleaner display.
#   Pass --legend to show the legend. Falls back to system ping if
#   prettyping is not installed.
#
# ARGUMENTS
#   --legend  Show the prettyping legend (overrides default --nolegend)
#   args...   Arguments forwarded to prettyping or system ping
#
# EXAMPLE
#   ping google.com
#   ping --legend google.com
function ping --description 'prettyping with default nolegend'
    # Opinionated guard (C1): fall back to bare command ping when disabled.
    if not __fish_config_op_enabled __fish_config_op_aliases
        command ping $argv
        return $status
    end

    if command -q prettyping
        # Check if the user specifically asked for the legend
        if contains -- --legend $argv
            command prettyping $argv
        else
            command prettyping --nolegend $argv
        end
    else
        # Fallback to standard ping if prettyping isn't installed
        command ping $argv
    end
end
