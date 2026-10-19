# Copyright (C) 2026 Rootiest
# SPDX-License-Identifier: AGPL-3.0-or-later

# CATEGORY
#   04-git-and-version-control
#
# DEPENDENCIES
#   git-sweep
#
# CLASSIFICATION
#   network, destructive
#
# SYNOPSIS
#   git-clean [-h] [-f]
#
# DESCRIPTION
#   Deprecated: use git-sweep. Prints a notice on stderr, then runs
#   git-sweep --local-only, which keeps git-clean's old scope (it never
#   touched remote branches) with git-sweep's merge detection. Branches are
#   now also deleted when fully merged, not only when their remote branch
#   is gone, and rebase and squash merges count as merged.
#
#   Not the built-in git clean, which deletes untracked files.
#
# ARGUMENTS
#   -h, --help   Show help message
#   -f, --force  Passed on as git-sweep --force
#
# EXIT STATUS
#   0  Cleanup complete
#   1  A branch could not be deleted
#   2  Unknown option or unexpected argument
#
# EXAMPLE
#   git-clean --force
#   git-clean
function git-clean --description 'Deprecated: use git-sweep'
    __fish_help_header (status current-function) $argv; and return 0

    argparse f/force -- $argv
    or return
    __fish_no_args (status current-function) $argv; or return

    __fish_palette
    echo "$c_warn""git-clean is deprecated; use$c_reset $c_cmd""git-sweep$c_reset$c_warn. Running git-sweep --local-only.$c_reset" >&2

    set -l args --local-only
    set -q _flag_force; and set -a args --force
    git-sweep $args
end
