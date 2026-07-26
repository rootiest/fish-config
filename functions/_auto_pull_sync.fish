# Copyright (C) 2026 Rootiest
# SPDX-License-Identifier: AGPL-3.0-or-later

# SYNOPSIS
#   _auto_pull_sync <dir>
#
# DESCRIPTION
#   Best-effort, side-effect-safe fast-forward of a single git repository.
#   Performs a fetch and a fast-forward-only merge of the current branch's
#   upstream, but only when it is completely safe to do so: the work tree
#   must be clean, the branch must have an upstream, and the merge must be a
#   true fast-forward. Any failed precondition makes the function a no-op.
#   It never rebases, never creates a merge commit, and never overwrites
#   committed or uncommitted work — worst case it does nothing.
#
#   Intended to be invoked in the background by the auto-pull PWD handler
#   (conf.d/auto-pull.fish), but safe to call directly.
#
# ARGUMENTS
#   dir  Absolute path to the git repository to fast-forward
#
# EXIT STATUS
#   0  Fast-forward applied (or already up to date)
#   1  A precondition failed; nothing was changed
#
# EXAMPLE
#   _auto_pull_sync ~/.config/fish
function _auto_pull_sync --description 'Fast-forward a repo when clean and a ff is possible'
    set -l d $argv[1]
    test -n "$d"; or return 1

    # Must be a git work tree.
    command git -C "$d" rev-parse --is-inside-work-tree >/dev/null 2>&1; or return 1

    # Work tree must be clean (no staged or unstaged changes).
    command git -C "$d" diff --quiet 2>/dev/null
    and command git -C "$d" diff --cached --quiet 2>/dev/null
    or return 1

    # Current branch must have an upstream to fast-forward against.
    command git -C "$d" rev-parse --abbrev-ref --symbolic-full-name '@{u}' >/dev/null 2>&1
    or return 1

    # Fetch, then fast-forward only. --ff-only aborts (no-op) on any divergence.
    command git -C "$d" fetch -q 2>/dev/null; or return 1
    command git -C "$d" merge -q --ff-only '@{u}' >/dev/null 2>&1
end
