# Copyright (C) 2026 Rootiest
# SPDX-License-Identifier: AGPL-3.0-or-later

# CATEGORY
#   04-git-and-version-control
#
# DEPENDENCIES
#   git
#
# CLASSIFICATION
#   blocking-prompt
#
# SYNOPSIS
#   gitignore-scrub [-h] [-r] [-w | -f | -i]
#
# DESCRIPTION
#   Finds files that are tracked by git but now match a .gitignore pattern
#   (git ls-files -ci --exclude-standard) and offers to untrack them. In the
#   default interactive mode, prompts once for all matches and runs
#   git rm --cached on confirmation; a decline is remembered per-path in the
#   repo's local git config (gitignore-scrub.skip) so the same file is not
#   asked about again. -w/--warn is read-only: prints a Warning line per
#   match and makes no changes, meant for non-interactive callers such as a
#   git hook. -f/--force skips the prompt and untracks every match
#   immediately. -i/--individual prompts once per file instead of once for
#   the whole group. -w, -f, and -i are mutually exclusive. -r/--reset
#   clears the repo's skip list first (combinable with any mode), so
#   previously declined files are reconsidered. Silently does nothing on a
#   repo with more tracked files than $GITIGNORE_SCRUB_LIMIT (default
#   5000), to avoid adding latency to huge repos.
#
# ARGUMENTS
#   -h, --help        Show help message
#   -r, --reset       Clear the remembered skip list before checking
#   -w, --warn        Read-only: print warnings instead of prompting, make no changes
#   -f, --force       Untrack every match immediately, no prompt
#   -i, --individual  Prompt once per file instead of once for the whole group
#
# EXIT STATUS
#   0  Clean, or a prompt/force run was handled
#   1  Not a git repository, or (-w only) unconfirmed matches were found
#
# EXAMPLE
#   gitignore-scrub
#   gitignore-scrub --warn
#   gitignore-scrub --force
#   gitignore-scrub --individual
#   gitignore-scrub --reset
function gitignore-scrub --description 'Find and optionally untrack files newly matched by .gitignore'
    argparse --exclusive w,f,i h/help r/reset w/warn f/force i/individual -- $argv
    or return 1

    if set -q _flag_help
        __fish_palette
        echo "$c_head""Usage:$c_reset $c_cmd""gitignore-scrub$c_reset $c_arg""[FLAGS]$c_reset"
        echo ""
        echo "$c_head""Flags:$c_reset"
        echo "  $c_flag-h, --help$c_reset       Show this help message"
        echo "  $c_flag-r, --reset$c_reset      Clear the remembered skip list before checking"
        echo "  $c_flag-w, --warn$c_reset       Read-only: print warnings instead of prompting"
        echo "  $c_flag-f, --force$c_reset      Untrack every match immediately, no prompt"
        echo "  $c_flag-i, --individual$c_reset Prompt once per file instead of once for the group"
        echo ""
        echo "$c_head""Examples:$c_reset"
        echo "  $c_cmd""gitignore-scrub$c_reset             $c_dim""# Interactive: prompt to untrack matches$c_reset"
        echo "  $c_cmd""gitignore-scrub --warn$c_reset      $c_dim""# Read-only: for use in a git hook$c_reset"
        echo "  $c_cmd""gitignore-scrub --force$c_reset     $c_dim""# Untrack every match, no prompt$c_reset"
        echo "  $c_cmd""gitignore-scrub --individual$c_reset $c_dim""# Prompt per file instead of as a group$c_reset"
        echo "  $c_cmd""gitignore-scrub --reset$c_reset     $c_dim""# Reconsider previously declined files$c_reset"
        return 0
    end

    if not git rev-parse --is-inside-work-tree >/dev/null 2>&1
        set_color red --bold
        echo "Error:" (set_color normal)"Not a git repository (or any parent directories)" >&2
        return 1
    end

    set -l limit 5000
    set -q GITIGNORE_SCRUB_LIMIT; and set limit $GITIGNORE_SCRUB_LIMIT

    set -l tracked_count (git ls-files | count)
    if test $tracked_count -gt $limit
        return 0
    end

    set -l offenders (git ls-files -ci --exclude-standard)
    set -q offenders[1]; or return 0

    if set -q _flag_reset
        git config --local --remove-section gitignore-scrub 2>/dev/null
    end

    set -l skip_list (git config --local --get-all gitignore-scrub.skip 2>/dev/null)
    set -l pending
    for f in $offenders
        contains -- "$f" $skip_list; or set -a pending $f
    end
    set -q pending[1]; or return 0

    if set -q _flag_warn
        for f in $pending
            set_color yellow --bold
            echo -n "Warning: "
            set_color normal
            echo "$f is tracked but ignored"
        end
        return 1
    end

    if set -q _flag_force
        git rm --cached -- $pending >/dev/null
        echo (set_color green)"✔"(set_color normal)" Untracked "(count $pending)" file(s)."
        return 0
    end

    if set -q _flag_individual
        for f in $pending
            read -P "Remove '$f' from git tracking? [y/N] " confirm
            if string match -qir '^y' -- "$confirm"
                git rm --cached -- "$f" >/dev/null
                echo (set_color green)"✔"(set_color normal)" Untracked $f"
            else
                git config --local --add gitignore-scrub.skip "$f"
            end
        end
        return 0
    end

    set_color yellow
    echo (count $pending)" tracked file(s) now match .gitignore:"(set_color normal)
    for f in $pending
        echo "  $f"
    end
    read -P "Remove from git tracking? [y/N] " confirm
    if string match -qir '^y' -- "$confirm"
        git rm --cached -- $pending >/dev/null
        echo (set_color green)"✔"(set_color normal)" Untracked "(count $pending)" file(s)."
    else
        for f in $pending
            git config --local --add gitignore-scrub.skip "$f"
        end
        echo (set_color brblack)"Remembered — won't ask again for these files."(set_color normal)
    end
end
