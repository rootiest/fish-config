# Copyright (C) 2026 Rootiest
# SPDX-License-Identifier: AGPL-3.0-or-later

# SYNOPSIS
#   __fish_variable_check <variable_name>
#
# DESCRIPTION
#   Evaluates a given variable's value to determine its truthiness or falsiness.
#   It safely dereferences the variable name and performs case-insensitive matching.
#
# ARGUMENTS
#   variable_name  The name of the variable to check (e.g., __fish_config_strict_mode)
#                  Do NOT pass the value directly (do not use the $ prefix).
#
# RETURNS
#   0  True    (Opt-In)  : Matches 1, true, yes, on, y
#   1  False   (Opt-Out) : Matches 0, false, no, off, n
#   2  Empty             : Variable is unset or contains an empty string
#   3  Garbage           : Variable contains an unrecognized value
#
# EXAMPLE
#   __fish_variable_check __fish_config_strict_mode
#   if test $status -eq 0
#       echo "Strict mode enabled!"
#   end
#
function __fish_variable_check --description "Check if a variable is set to a truthy or falsy value."
    set -l var_name $argv[1]

    # Make sure they actually passed an argument
    if test -z "$var_name"
        return 2
    end

    # 2: Empty / Unset (Check if the variable exists in the environment at all)
    if not set -q $var_name
        return 2
    end

    # Dereference the variable name to get its actual value using $$
    set -l val (string lower "$$var_name")

    # 2: Empty / Unset (Check if it exists but is just an empty string)
    if test -z "$val"
        return 2
    end

    # 0: True (Opt-In)
    if contains -- "$val" 1 true yes on y
        return 0
    end

    # 1: False (Opt-Out)
    if contains -- "$val" 0 false no off n
        return 1
    end

    # 3: Garbage / Unrecognized
    return 3
end
