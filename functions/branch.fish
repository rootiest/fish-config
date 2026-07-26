# Copyright (C) 2026 Rootiest
# SPDX-License-Identifier: AGPL-3.0-or-later

# CATEGORY
#   04-git-and-version-control
#
# SYNOPSIS
#   branch <branch_name>
#
# DESCRIPTION
#   Switches to a local git branch, creating it if it does not already
#   exist. Extra arguments are forwarded to git checkout.
#
# ARGUMENTS
#   branch_name   Branch to switch to or create
#
# EXIT STATUS
#   0  Branch checked out or created
#   1  Not inside a git work tree
#
# EXAMPLE
#   branch feature/new-ui
function branch --description 'Switch to or create a git branch'
    if not git rev-parse --is-inside-work-tree >/dev/null 2>&1
        echo "Not a git repo."
        return 1
    end
    
    # Check if the branch already exists locally
    if git show-ref --verify --quiet refs/heads/$argv[1]
        git checkout $argv
    else
        # If it doesn't exist, create it
                git checkout -b $argv
        end
end
