# Copyright (C) 2026 Rootiest
# SPDX-License-Identifier: AGPL-3.0-or-later

# SYNOPSIS
#   __fish_config_op_enabled <category_variable>
#
# DESCRIPTION
#   Guard predicate for opinionated components (AGENTS.md Task #3). The master
#   switch __fish_config_opinionated is always evaluated first via
#   __fish_variable_check: a falsy master value (0/false/no/off/n) disables
#   every category at once, regardless of the category variable's own value.
#   Otherwise the supplied category variable is evaluated the same way.
#   Unset or empty variables (status 2) and unrecognized values (status 3)
#   leave the component enabled — opinionated components are active by
#   default and these variables are pure opt-out knobs.
#
# ARGUMENTS
#   category_variable  Name (without $) of the category opt-out variable:
#                      __fish_config_op_aliases, __fish_config_op_autoexec,
#                      __fish_config_op_overrides, or
#                      __fish_config_op_integrations
#
# RETURNS
#   0  Component enabled (variables truthy, unset, or unrecognized)
#   1  Component disabled (master or category variable is falsy)
#
# EXAMPLE
#   if __fish_config_op_enabled __fish_config_op_aliases
#       alias grep='grep --color=auto'
#   end
function __fish_config_op_enabled --description 'Check whether an opinionated component category is enabled'
    # Master switch first: falsy disables all categories unconditionally.
    __fish_variable_check __fish_config_opinionated
    if test $status -eq 1
        return 1
    end

    # Category variable: only an explicit falsy value disables the category.
    # Truthy (0), unset/empty (2), and garbage (3) all keep it enabled.
    __fish_variable_check $argv[1]
    if test $status -eq 1
        return 1
    end

    return 0
end
