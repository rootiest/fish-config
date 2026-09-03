# Copyright (C) 2026 Rootiest
# SPDX-License-Identifier: AGPL-3.0-or-later

# SYNOPSIS
#   _agents_repo_sync <dir> <message>
#
# DESCRIPTION
#   Pulls (when an upstream is configured), stages everything, and commits
#   with <message>. Shared by agents-init and agents-vault.
#
#   A failed rebase is aborted and nothing is committed. Committing blindly
#   after a failed pull would stage conflict markers and record them under a
#   routine-looking message, so the failure is surfaced instead: the repo is
#   left clean at local HEAD for the user to resolve by hand.
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
#   2  Rebase conflict; aborted, nothing committed
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

    if git -C "$dir" rev-parse --abbrev-ref --symbolic-full-name '@{u}' >/dev/null 2>&1
        if not git -C "$dir" pull --rebase --autostash -q >/dev/null 2>/dev/null
            git -C "$dir" rebase --abort >/dev/null 2>/dev/null
            echo "_agents_repo_sync: rebase conflict in $dir; aborted, left at local HEAD" >&2
            return 2
        end
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
