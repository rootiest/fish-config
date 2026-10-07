# Copyright (C) 2026 Rootiest
# SPDX-License-Identifier: AGPL-3.0-or-later

# SYNOPSIS
#   __fish_no_args FUNCTION ARGS...
#
# DESCRIPTION
#   For a function that takes no arguments: fails with a usage error naming
#   the first one given, so a typo such as upgrade --dry-run never reaches
#   the function's real work (CONTRIBUTING.md, Help requests, rule 9). Call
#   it right after the help check, which has already answered -h/--help.
#
# EXIT STATUS
#   0  ARGS is empty
#   2  An argument was given
#
# EXAMPLE
#   __fish_no_args (status current-function) $argv; or return
function __fish_no_args --argument-names fn
    set -q argv[2]; or return 0
    __fish_palette
    echo "$c_err$fn: unexpected argument '$argv[2]'$c_reset" >&2
    echo "Run $c_cmd$fn --help$c_reset for usage." >&2
    return 2
end
