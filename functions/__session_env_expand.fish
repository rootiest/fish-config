# Copyright (C) 2026 Rootiest
# SPDX-License-Identifier: AGPL-3.0-or-later

# SYNOPSIS
#   __session_env_expand VALUE [NAME=VALUE...]
#
# DESCRIPTION
#   Expands an environment.d value the way systemd would, against the
#   NAME=VALUE pairs given after it: ${NAME} and ${NAME:-default}
#   (defaults may nest, as in ${A:-${B}/x}) are substituted, then "$$"
#   becomes a literal dollar sign. An unset or empty NAME takes its
#   default, or nothing when it has none. Used by session-env's "apply
#   now" to resolve a catalog value against the running user manager.
#
# EXIT STATUS
#   0  Always
#
# RETURNS
#   The expanded value on stdout
#
# EXAMPLE
#   __session_env_expand '${XDG_CACHE_HOME:-${HOME}/.cache}/go' HOME=/home/u
function __session_env_expand --description 'Expand environment.d ${VAR:-default} references'
    set -l v $argv[1]
    set -l env_pairs $argv[2..]
    # Innermost reference first; the cap stops a value that expands to
    # another reference from looping forever.
    for pass in (seq 50)
        set -l m (string match -r '\$\{([A-Za-z_][A-Za-z0-9_]*)(?::-([^${}]*))?\}' -- $v)
        set -q m[1]; or break
        set -l cur ''
        for p in $env_pairs
            if string match -q -- "$m[2]=*" $p
                set cur (string replace -- "$m[2]=" '' $p)
                break
            end
        end
        set -l repl $cur
        test -z "$cur"; and set repl "$m[3]"
        set v (string replace -- $m[1] "$repl" $v)
    end
    # string replace exits 1 when nothing changed, so print through printf.
    set v (string replace -a -- '$$' '$' $v)
    printf '%s\n' $v
end
