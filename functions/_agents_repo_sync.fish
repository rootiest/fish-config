# Copyright (C) 2026 Rootiest
# SPDX-License-Identifier: AGPL-3.0-or-later

# SYNOPSIS
#   _agents_repo_sync <dir> <message>
#
# DESCRIPTION
#   Stages everything in <dir> and commits it with <message>. Shared by
#   agents-init and agents-vault.
#
#   It never touches the network, and that is the point rather than an
#   omission. Both callers run on every agent launch, synchronously, ahead
#   of the agent itself, and a fetch there blocks the launch for as long as
#   an unreachable remote takes to time out and can prompt for credentials
#   invisibly underneath a starting agent. Committing needs no remote at
#   all -- only pushing does -- so the pull lives on agents-vault's push
#   path, which is already opt-in for exactly this reason. An offline
#   laptop therefore still gets a complete local backup, which is the whole
#   point of keeping one.
#
#   A rebase already in progress is refused rather than committed: the
#   worktree then holds conflict markers, and recording those under a
#   routine-looking message buries the conflict in the history instead of
#   reporting it. The rebase is left exactly as it stands -- this function
#   did not start it, so it is not this function's to abort -- and the
#   caller says so.
#
#   Commits are made with commit.gpgsign=false so a pinentry prompt can
#   never block a shell or an agent launch. If a pre-commit or commit-msg
#   hook rejects the commit (e.g. a secret scanner), that failure is
#   surfaced too: nothing is committed and a diagnostic goes to stderr.
#
# ARGUMENTS
#   dir      Absolute path to the git repository
#   message  Commit subject used when there is something to commit
#
# EXIT STATUS
#   0  Committed, or nothing needed committing
#   1  <dir> is not a git repository, arguments were missing, or the commit
#      itself failed (e.g. a pre-commit/commit-msg hook rejected it)
#   2  A rebase is in progress; nothing committed, nothing touched
#
# RETURNS
#   A single "→ Committed (<sha>) <subject>" line on stdout when it
#   commits; nothing when there was nothing to do.
#
# EXAMPLE
#   _agents_repo_sync /path/to/AGENTS "chore: sync AGENTS repository"
function _agents_repo_sync --argument-names dir msg
    test -n "$dir" -a -n "$msg"; or return 1
    test -d "$dir/.git"; or return 1

    # The guard above proved .git is a directory, so these are the same two
    # paths `agents-vault --status` reports an unresolved rebase from.
    if test -d "$dir/.git/rebase-merge"; or test -d "$dir/.git/rebase-apply"
        echo "_agents_repo_sync: unresolved rebase in $dir; nothing committed" >&2
        return 2
    end

    git -C "$dir" add -A 2>/dev/null
    set -l status_out (git -C "$dir" status --porcelain 2>/dev/null)
    test -n "$status_out"; or return 0

    if git -C "$dir" -c commit.gpgsign=false commit -q -m "$msg" 2>/dev/null
        set -l sha (git -C "$dir" rev-parse --short HEAD 2>/dev/null)
        set -l subject (git -C "$dir" log -1 --pretty=%s 2>/dev/null)
        echo "→ Committed ($sha) $subject"
        return 0
    else
        echo "_agents_repo_sync: commit failed in $dir (hook rejected it?); nothing committed" >&2
        return 1
    end
end
