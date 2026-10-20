# Copyright (C) 2026 Rootiest
# SPDX-License-Identifier: AGPL-3.0-or-later

# CATEGORY
#   01-file-and-directory
#
# COMPONENT
#   aliases/filesystem
#
# CLASSIFICATION
#   bypasses-shadow(cp)
#
# SYNOPSIS
#   cp [args...]
#
# DESCRIPTION
#   Wraps cp so it asks before overwriting: it passes -i, as the old
#   cp -i alias in conf.d/tricks.fish did. A flag you pass after it, such
#   as -f or -n, still wins.
#
#   It is a function rather than an alias because an alias is itself a
#   function named cp and would shadow this one.
#
#   Opinionated component (C1): when disabled via __fish_config_op_aliases
#   or its aliases/filesystem sub-category (__fish_config_op_aliases_filesystem),
#   behaves exactly like bare command cp, with no -i.
#
# ARGUMENTS
#   args...  Arguments forwarded to standard cp
#
# EXIT STATUS
#   Standard cp exit status.
#
# EXAMPLE
#   cp notes.txt notes.bak
function cp --wraps='cp' --description 'Copy files, asking before overwriting'
    # Opinionated guard (C1): fall back to bare command cp when disabled.
    if not __fish_config_op_enabled (status current-function)
        command cp $argv
        return $status
    end

    # -i goes first so a -f or -n from the caller overrides it.
    command cp -i $argv
end
