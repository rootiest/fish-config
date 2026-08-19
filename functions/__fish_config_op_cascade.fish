# Copyright (C) 2026 Rootiest
# SPDX-License-Identifier: AGPL-3.0-or-later

# SYNOPSIS
#   __fish_config_op_cascade <category_variable> [<subcategory_variable>]
#
# DESCRIPTION
#   Evaluates the opt-out cascade for one C1-C6 classification: an
#   explicit truthy/falsy sub-category variable wins outright; otherwise
#   falls back to the category variable; otherwise falls back to the
#   master switch __fish_config_opinionated. A category in the opt-in
#   list (currently just __fish_config_op_logging, C5) defaults to
#   disabled when nothing in the chain is explicit, and the master switch
#   cannot enable it -- this is data-driven here instead of a hardcoded
#   string comparison, so any sub-category nested under an opt-in
#   category inherits "off unless explicit" for free through the cascade,
#   with no per-sub-category special-casing.
#
# ARGUMENTS
#   category_variable     Name (without $) of a C1-C6 category variable
#   subcategory_variable  Optional name (without $) of a sub-category
#                          variable nested under that category
#
# EXIT STATUS
#   0  Enabled
#   1  Disabled
#
# EXAMPLE
#   __fish_config_op_cascade __fish_config_op_aliases
#   __fish_config_op_cascade __fish_config_op_aliases __fish_config_op_aliases_filesystem
function __fish_config_op_cascade --description 'Evaluate the sub-category -> category -> master opt-out cascade'
    set -l opt_in_categories __fish_config_op_logging

    set -l chain $argv[1]
    if test (count $argv) -ge 2 -a -n "$argv[2]"
        set chain $argv[2] $argv[1]
    end

    for var_name in $chain
        __fish_variable_check $var_name
        set -l s $status
        if test $s -eq 0
            return 0
        end
        if test $s -eq 1
            return 1
        end
    end

    # Every variable in the chain was unset/unrecognized. chain[-1] is
    # always the category variable (present whether or not a
    # sub-category was given) -- opt-in categories default to disabled
    # and the master switch cannot override that.
    if contains -- $chain[-1] $opt_in_categories
        return 1
    end

    __fish_variable_check __fish_config_opinionated
    if test $status -eq 1
        return 1
    end
    return 0
end
