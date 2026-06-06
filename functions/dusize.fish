# Copyright (C) 2026 Rootiest
# SPDX-License-Identifier: AGPL-3.0-or-later

# SYNOPSIS
#   dusize [dir]
#
# DESCRIPTION
#   Shows a human-readable disk usage summary using du -sh. Defaults to the
#   current directory if no argument is given.
#
# ARGUMENTS
#   dir  Directory to summarize (defaults to current directory)
#
# EXAMPLE
#   dusize ~/Downloads
function dusize --wraps='du' --description 'alias dusize=du'
    du -sh (test -n "$argv[1]"; and echo $argv[1]; or echo .)
end
