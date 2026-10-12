# Copyright (C) 2026 Rootiest
# SPDX-License-Identifier: AGPL-3.0-or-later

# SYNOPSIS
#   _fish_source_scoped <file>
#
# DESCRIPTION
#   Sources <file> inside its own function-call boundary. `source` runs
#   in the caller's own scope, so a bare `return` in a sourced file --
#   used by several conf.d guards as an early exit -- would otherwise
#   unwind whatever function called `source` directly, not just the
#   sourced file. Calling through this helper contains it to here.
#
# ARGUMENTS
#   file  Path to the fish script to source
#
# EXIT STATUS
#   0  File does not exist (nothing to do)
#   2  No argument, or an empty one (nothing is sourced)
#   Exit status of the sourced file otherwise
#
# EXAMPLE
#   _fish_source_scoped $__fish_config_dir/conf.d/pkg-wrappers.fish
function _fish_source_scoped --argument-names file
    # Quoted, and the empty case refused up front: with no argument an
    # unquoted `test -f $file` collapses to `test -f`, which is true, and
    # the bare `source` that follows would execute stdin.
    test -n "$file"; or return 2
    test -f "$file"; or return 0
    source $file
end
