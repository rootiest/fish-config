# Copyright (C) 2026 Rootiest
# SPDX-License-Identifier: AGPL-3.0-or-later

# SYNOPSIS
#   __fish_help_requested ARGS...
#
# DESCRIPTION
#   Succeeds when -h or --help appears anywhere in ARGS before a --. This is
#   the shared check behind the help convention for subcommand-style
#   functions (CONTRIBUTING.md, Help requests). Matching is exact, so HELP,
#   -help and a bare help do not count; a caller checks a bare help in its
#   subcommand slot itself.
#
# EXIT STATUS
#   0  A help flag appears before --
#   1  None does
#
# EXAMPLE
#   __fish_help_requested $argv; and __my_fn_help; and return 0
function __fish_help_requested
    for a in $argv
        test "$a" = --; and return 1
        contains -- $a -h --help; and return 0
    end
    return 1
end
