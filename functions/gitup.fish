# Copyright (C) 2026 Rootiest
# SPDX-License-Identifier: AGPL-3.0-or-later

# CATEGORY
#   04-git-and-version-control
#
# SYNOPSIS
#   gitup [args...]
#
# DESCRIPTION
#   Fetches updates from the remote and shows git status. Extra arguments
#   are forwarded to git fetch.
#
# ARGUMENTS
#   args...   Forwarded verbatim to git fetch
#
# RETURNS
#   0  Fetch and status succeeded
#   1  Not inside a git work tree
#
# EXAMPLE
#   gitup
#   gitup --all
function gitup --description 'Fetch updates and show git status'
    # Check if we are even in a git repository
    if not git rev-parse --is-inside-work-tree >/dev/null 2>&1
        echo "Check your map! You aren't in a git repository."
        return 1
    end
    
    if count $argv >/dev/null
        git fetch $argv
    else
        git fetch
    end
    
    and git status
end
