# Copyright (C) 2026 Rootiest
# SPDX-License-Identifier: AGPL-3.0-or-later

# SYNOPSIS
#   __fish_config_op_enabled <identity> [<site>]
#
# DESCRIPTION
#   Guard predicate for an opinionated component. <identity> is computed
#   by the caller, never hand-typed as a category name: (status
#   current-function) inside a function body, (status basename) at
#   top-level conf.d/*.fish or config.fish code (fish has no API for a
#   callee to introspect its own caller, so the caller must compute and
#   pass its own identity -- see the spec's "A note on self-identifying").
#   A trailing .fish is stripped so a status-basename identity and a
#   status-current-function identity land in the same key space.
#
#   Looks up "<identity>:<site>" (site defaults to the empty/unnamed site)
#   in the generated component registry. No registry entry (unclassified,
#   or a doc header with no # COMPONENT section) resolves to enabled --
#   the same fail-open default as an explicit `always/on` tag, so
#   user-authored and third-party functions that never call this guard in
#   the first place are unaffected, and one that somehow does is never
#   silently broken by a missing header. A found `always/off` tag
#   disables unconditionally; a found `always/on` tag enables
#   unconditionally, short-circuiting before any other tagged
#   sub-category is evaluated. Otherwise every tagged sub-category must
#   pass the cascade (AND semantics).
#
# ARGUMENTS
#   identity  (status current-function) or (status basename)
#   site      Optional site slug (see # COMPONENT header grammar);
#             omitted for the default/unnamed site
#
# EXIT STATUS
#   0  Component enabled
#   1  Component disabled
#
# EXAMPLE
#   if not __fish_config_op_enabled (status current-function)
#       alias grep='grep --color=auto'
#   end
#   if not __fish_config_op_enabled (status current-function) exit-plain
#       builtin exit
#   end
function __fish_config_op_enabled --description 'Guard for an opinionated component, identified by its own caller'
    set -l identity (string replace -r '\.fish$' '' -- $argv[1])
    set -l site $argv[2]

    set -l tags (__fish_config_op_registry_lookup $identity $site)
    if test $status -ne 0
        return 0
    end

    if contains -- always/off $tags
        return 1
    end
    if contains -- always/on $tags
        return 0
    end

    for tag in $tags
        set -l parts (string split -m 1 -- / $tag)
        set -l category_var "__fish_config_op_$parts[1]"
        set -l subcat_var "__fish_config_op_$parts[1]_"(string replace -a -- '-' '_' $parts[2])
        __fish_config_op_cascade $category_var $subcat_var
        or return 1
    end
    return 0
end
