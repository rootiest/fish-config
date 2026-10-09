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
        # Status 3 = set but unrecognized (e.g. "ture", "disabled"). The
        # value is ignored exactly as before; the only addition is a warning,
        # once per variable per session (deduped via a global list). Nothing
        # here runs for valid, unset or empty values, so startup pays nothing.
        if test $s -eq 3
            if not contains -- $var_name $__fish_op_warned_values
                set -g __fish_op_warned_values $__fish_op_warned_values $var_name
                __fish_palette
                printf '%s%s%s is set to %s%s%s; expected one of on/off/1/0/true/false/yes/no/y/n %s-- ignoring%s\n' \
                    $c_cmd $var_name $c_reset $c_err "$$var_name" $c_reset $c_dim $c_reset >&2
            end
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
    set -l m $status
    if test $m -eq 3
        if not contains -- __fish_config_opinionated $__fish_op_warned_values
            set -g __fish_op_warned_values $__fish_op_warned_values __fish_config_opinionated
            __fish_palette
            printf '%s%s%s is set to %s%s%s; expected one of on/off/1/0/true/false/yes/no/y/n %s-- ignoring%s\n' \
                $c_cmd __fish_config_opinionated $c_reset $c_err "$__fish_config_opinionated" $c_reset $c_dim $c_reset >&2
        end
    end
    if test $m -eq 1
        return 1
    end
    return 0
end
