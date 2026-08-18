# Copyright (C) 2026 Rootiest
# SPDX-License-Identifier: AGPL-3.0-or-later

# SYNOPSIS
#   __fish_config_op_registry_lookup <identity> <site>
#
# DESCRIPTION
#   Looks up the "<identity>:<site>" key in the generated component
#   registry ($__fish_config_op_registry_keys /
#   $__fish_config_op_registry_values, sourced from
#   conf.d/__fish_config_op_registry.fish at shell startup) and prints its
#   tags, one per line. <site> is empty string for the default/unnamed
#   site.
#
# ARGUMENTS
#   identity  Function name (status current-function) or file basename
#             with any trailing .fish stripped (status basename)
#   site      Site slug, or empty string for the default site
#
# EXIT STATUS
#   0  Found: tags printed to stdout
#   1  Not found: nothing printed
#
# RETURNS
#   Matching tags, one per line, printed to stdout
#
# EXAMPLE
#   set -l tags (__fish_config_op_registry_lookup rm "")
#   or return 0   # unclassified: caller treats this as always-on
function __fish_config_op_registry_lookup --description 'Look up the COMPONENT tags for an identity:site pair'
    set -l key "$argv[1]:$argv[2]"
    set -l idx (contains -i -- $key $__fish_config_op_registry_keys)
    if test -z "$idx"
        return 1
    end
    string split ' ' -- $__fish_config_op_registry_values[$idx]
    return 0
end
