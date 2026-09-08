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
#   Exit status of the sourced file otherwise
#
# EXAMPLE
#   _fish_source_scoped $__fish_config_dir/conf.d/paru-wrapper.fish
function _fish_source_scoped --argument-names file
    test -f $file; or return 0
    source $file
end
