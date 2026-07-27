# Copyright (C) 2026 Rootiest
# SPDX-License-Identifier: AGPL-3.0-or-later

# SYNOPSIS
#   __fish_config_op_enabled <category_variable>
#
# DESCRIPTION
#   Guard predicate for opinionated components (AGENTS.md Task #3).
#   The category variable is evaluated first via __fish_variable_check:
#   an explicit truthy value (1/true/yes/on/y) enables the component
#   regardless of the master switch; an explicit falsy value
#   (0/false/no/off/n) disables it regardless of the master switch.
#   Only when the category variable is unset or unrecognized (status 2
#   or 3) does the master switch __fish_config_opinionated apply: a
#   falsy master disables every unset-category component at once.
#   Unset master with unset category → enabled (active by default).
#
#   One exception: __fish_config_op_logging (C5) is opt-in, because it
#   writes terminal output to disk. Unset or unrecognized means disabled,
#   and the master switch cannot enable it — only an explicit truthy
#   value turns logging on.
#
# ARGUMENTS
#   category_variable  Name (without $) of the category opt-out variable:
#                      __fish_config_op_aliases, __fish_config_op_autoexec,
#                      __fish_config_op_overrides,
#                      __fish_config_op_integrations,
#                      __fish_config_op_logging, or
#                      __fish_config_op_greeting
#
# EXIT STATUS
#   0  Component enabled (category explicitly truthy; or category unset and master not falsy — except C5 logging, which requires an explicit truthy value)
#   1  Component disabled (category explicitly falsy; or category unset and master falsy; or C5 logging unset; or no argument with falsy master)
#
# EXAMPLE
#   if __fish_config_op_enabled __fish_config_op_aliases
#       alias grep='grep --color=auto'
#   end
function __fish_config_op_enabled --description 'Check whether an opinionated component category is enabled'
    __fish_variable_check $argv[1]
    set -l cat_status $status

    if test $cat_status -eq 0
        return 0
    end

    if test $cat_status -eq 1
        return 1
    end

    # C5 logging is opt-in: it writes terminal output to disk, so an unset or
    # unrecognized value means off — the master switch cannot enable it.
    if test "$argv[1]" = __fish_config_op_logging
        return 1
    end

    # Status 3 (garbage) defers to master — an unrecognized value is not an opt-out.
    __fish_variable_check __fish_config_opinionated
    if test $status -eq 1
        return 1
    end

    return 0
end
