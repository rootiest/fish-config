# Copyright (C) 2026 Rootiest
# SPDX-License-Identifier: AGPL-3.0-or-later

# SYNOPSIS
#   _git_sweep_merged <ref> <base>
#
# DESCRIPTION
#   Succeeds when every change on <ref> is already in <base>, and prints how
#   it got there. Covers every merge strategy a forge offers:
#
#     merged         <ref> is an ancestor of <base> (merge commit or
#                    fast-forward)
#     rebase-merged  every commit on <ref> has a patch-equivalent on <base>
#                    (git cherry)
#     squash-merged  the whole diff of <ref> since the merge base matches
#                    one commit on <base>
#
#   The squash test builds a throwaway commit holding <ref>'s tree on top of
#   the merge base and asks git cherry whether <base> already has that
#   patch. It writes one unreferenced object, which git gc collects. If
#   conflicts were resolved differently on <base>, the patches differ and
#   the test fails: a branch is only ever kept by mistake, never deleted.
#
# EXIT STATUS
#   0  Merged
#   1  <ref> has changes that <base> lacks, or git failed
#
# RETURNS
#   One of: merged, rebase-merged, squash-merged
#
# EXAMPLE
#   _git_sweep_merged refs/heads/feat refs/remotes/origin/main
function _git_sweep_merged --argument-names ref base
    if git merge-base --is-ancestor $ref $base 2>/dev/null
        echo merged
        return 0
    end

    set -l cherry (git cherry $base $ref 2>/dev/null)
    or return 1
    if not string match -q '+*' -- $cherry
        echo rebase-merged
        return 0
    end

    set -l mb (git merge-base $base $ref 2>/dev/null)
    or return 1
    set -l tree (git rev-parse "$ref^{tree}" 2>/dev/null)
    or return 1
    set -l probe (GIT_AUTHOR_NAME=git-sweep GIT_AUTHOR_EMAIL=git-sweep@localhost \
        GIT_COMMITTER_NAME=git-sweep GIT_COMMITTER_EMAIL=git-sweep@localhost \
        git commit-tree $tree -p $mb -m git-sweep-probe 2>/dev/null)
    or return 1
    set -l probe_cherry (git cherry $base $probe 2>/dev/null)
    or return 1
    if string match -q -- '-*' $probe_cherry
        echo squash-merged
        return 0
    end
    return 1
end
