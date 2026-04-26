# Copyright (C) 2026 Rootiest
# SPDX-License-Identifier: AGPL-3.0-or-later

function git-clean --description 'Sync main, prune remotes, and delete orphaned branches'
    set -l options h/help f/force
    argparse $options -- $argv
    or return

    if set -q _flag_help
        echo (set_color --bold blue)"Usage: "(set_color normal)"git-clean [OPTIONS]"
        echo
        echo "Steps taken:"
        echo "  1. Fetches and prunes to find deleted remote branches."
        echo "  2. Switches to main if you are on an orphaned branch."
        echo "  3. Pulls the latest changes from the remote."
        echo "  4. Deletes local orphaned branches."
        return 0
    end

    # 1. Fetch and prune (Quietly)
    echo (set_color blue)"Fetching and pruning remote tracking..."(set_color normal)
    git fetch --prune --quiet

    # 2. Identify orphaned branches and current branch
    set -l gone_branches (git branch -vv | awk '/: gone\]/ {gsub(/\*/, ""); print $1}')
    set -l current_branch (git branch --show-current)

    if test -n "$gone_branches"
        # 3. Move to safety if needed (Quietly)
        if contains "$current_branch" $gone_branches
            echo (set_color yellow)"Current branch '$current_branch' was deleted on remote. Moving to main..."(set_color normal)
            # Redirecting output to /dev/null to hide the 'Switched to branch' message
            git checkout main >/dev/null 2>&1; or git checkout master >/dev/null 2>&1
        end
    end

    # 4. Update the current branch (Quietly)
    echo (set_color blue)"Updating current branch..."(set_color normal)
    git pull --quiet

    # 5. Final cleanup
    if test -n "$gone_branches"
        set -l delete_flag -d
        if set -q _flag_force
            set -l delete_flag -D
        end

        echo (set_color red)"Deleting orphaned local branches ($delete_flag):"(set_color normal)
        for branch in $gone_branches
            # We keep this output so you can see confirmation of which hashes were deleted
            git branch $delete_flag $branch
        end
    else
        echo (set_color green)"Everything is tidy. No orphaned branches found."(set_color normal)
    end
end
