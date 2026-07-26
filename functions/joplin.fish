# Copyright (C) 2026 Rootiest
# SPDX-License-Identifier: AGPL-3.0-or-later

# CATEGORY
#   14-miscellaneous
#
# SYNOPSIS
#   joplin [args...]
#
# DESCRIPTION
#   Runs the Joplin CLI with Node deprecation warnings suppressed via
#   NODE_OPTIONS=--no-deprecation.
#
# ARGUMENTS
#   args...  Arguments forwarded to the joplin command
#
# EXIT STATUS
#   0  Joplin ran successfully
#   1  joplin binary not found in PATH
#
# EXAMPLE
#   joplin ls
function joplin --description 'Run Joplin CLI without Node deprecation warnings'
    set -l joplin_path (command -v joplin)
    if test -n "$joplin_path"
        NODE_OPTIONS="--no-deprecation" $joplin_path $argv
    else
        echo "Error: joplin binary not found in PATH" >&2
        return 1
    end
end
