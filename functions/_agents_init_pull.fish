# Copyright (C) 2026 Rootiest
# SPDX-License-Identifier: AGPL-3.0-or-later

# CLASSIFICATION
#   network
#
# SYNOPSIS
#   _agents_init_pull <agents-dir>
#
# DESCRIPTION
#   Pulls an AGENTS/ sub-repository from its upstream with a rebase, for
#   agents-init --pull. The pull runs through _agents_repo_net_git, so it
#   cannot prompt and is capped at 20 seconds. Local commits are replayed
#   on top of the upstream ones (agents-init commits on every launch, so a
#   fast-forward-only pull would almost always refuse), and uncommitted
#   changes are autostashed. A rebase that stops on a conflict is aborted,
#   leaving the sub-repo at its local HEAD; it is this function's rebase,
#   so aborting it is this function's to do.
#
#   A sub-repo with no upstream is not an error: there is nothing to pull.
#   A rebase that was already in progress before the call is refused and
#   left alone.
#
# ARGUMENTS
#   agents-dir  The AGENTS/ directory (root of its own repository)
#
# EXIT STATUS
#   0  Pulled, already current, or no upstream configured
#   1  The remote could not be reached (or git failed for another reason)
#   2  The rebase conflicted and was aborted; local HEAD is intact
#   3  A rebase was already in progress; nothing was done
#   4  timeout(1) is unavailable; nothing was run
#
# RETURNS
#   One word on stdout when the status is 0: "updated", "current" or
#   "no-upstream".
#
# EXAMPLE
#   _agents_init_pull $root/AGENTS
function _agents_init_pull
    set -l d $argv[1]
    test -d "$d/.git"; or return 1

    if test -d "$d/.git/rebase-merge"; or test -d "$d/.git/rebase-apply"
        return 3
    end

    if not command git -C "$d" rev-parse --abbrev-ref --symbolic-full-name '@{u}' >/dev/null 2>&1
        echo no-upstream
        return 0
    end

    set -l before (command git -C "$d" rev-parse HEAD 2>/dev/null)
    _agents_repo_net_git "$d" 20 pull --rebase --autostash -q >/dev/null 2>&1
    set -l rc $status
    test $rc -eq 4; and return 4
    if test $rc -ne 0
        # A rebase that really started and stopped leaves one of these
        # behind; an unreachable remote never began one.
        if test -d "$d/.git/rebase-merge"; or test -d "$d/.git/rebase-apply"
            command git -C "$d" rebase --abort >/dev/null 2>&1
            return 2
        end
        return 1
    end

    set -l after (command git -C "$d" rev-parse HEAD 2>/dev/null)
    if test "$before" = "$after"
        echo current
    else
        echo updated
    end
end
