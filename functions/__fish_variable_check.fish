# Copyright (C) 2026 Rootiest
# SPDX-License-Identifier: AGPL-3.0-or-later

# SYNOPSIS
#   __fish_variable_check <variable_name>
#
# DESCRIPTION
#   Evaluates a given variable's value to determine its truthiness or falsiness.
#   Safely dereferences the variable name and performs case-insensitive matching.
#   Pass the variable name (without $), not its value.
#
# ARGUMENTS
#   variable_name  Name of the variable to check (without $ prefix)
#
# EXIT STATUS
#   0  True (opt-in): value matches 1, true, yes, on, or y
#   1  False (opt-out): value matches 0, false, no, off, or n
#   2  Empty: variable is unset or empty
#   3  Garbage: value is unrecognized
#
# EXAMPLE
#   __fish_variable_check __fish_config_strict_mode
#   if test $status -eq 0
#       echo "Strict mode enabled!"
#   end
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
