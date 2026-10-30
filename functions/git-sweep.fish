# Copyright (C) 2026 Rootiest
# SPDX-License-Identifier: AGPL-3.0-or-later

# CATEGORY
#   04-git-and-version-control
#
# DEPENDENCIES
#   git, _git_sweep_merged, _git_sweep_open_prs
#
# CLASSIFICATION
#   network, destructive
#
# SYNOPSIS
#   git-sweep [-n] [-f] [-l] [-r <remote>] [-k <branch>]...
#
# DESCRIPTION
#   Sweeps up after merged work. Fetches and prunes the remote,
#   fast-forwards the local default branch, and deletes every branch whose
#   content is already in the default branch:
#
#     - Local branches merged into <remote>/<default>, by any strategy:
#       merge commit, fast-forward, rebase, or squash.
#     - Local branches whose remote branch is gone. Gone branches with
#       unmerged commits are kept unless -f is given.
#     - Remote branches merged into <remote>/<default>, unless they are the
#       head of an open pull request (a local branch tracking one is kept
#       too).
#
#   Open pull requests are listed with whatever is available: gh, tea or
#   glab, else curl with a token from the environment that belongs to the
#   remote's host, else anonymous curl for a public repository. If none of
#   them works, remote branches are listed but not deleted. Local cleanup
#   never needs any of them.
#
#   Never deleted: the default branch, main, master, develop, dev, trunk,
#   staging, production, gh-pages, release/*, any -k branch, branches
#   checked out in another worktree, local branches created but never
#   committed to, and any branch with unmerged commits whose remote branch
#   still exists. Unmerged remote branches are never deleted, even with -f.
#
#   If the current branch is deleted, git-sweep switches to the default
#   branch first; if tracked files have uncommitted changes, it keeps the
#   branch instead. If the fetch fails, it carries on offline against the
#   last fetched state and skips remote deletion: anything merged into a
#   stale <remote>/<default> is merged into the current one too.
#
#   Every local deletion prints the branch's last commit, so it can be
#   restored with git branch <name> <sha>.
#
# ARGUMENTS
#   -n, --dry-run        Print the plan; fetch, but change nothing else
#   -f, --force          Also delete gone local branches with unmerged commits
#   -l, --local-only     Never delete remote branches
#   -r, --remote NAME    Remote to sync and prune (default: origin)
#   -k, --keep BRANCH    Never delete BRANCH, local or remote; repeatable
#   -h, --help           Show this help message
#
# EXIT STATUS
#   0  Cleanup complete, or a dry run (-n) finished
#   1  A deletion failed (e.g. branch protection on the remote)
#   2  Unknown option, unexpected argument, not a git work tree, or no
#      default branch could be found
#
# EXAMPLE
#   git-sweep --dry-run
#   git-sweep
#   git-sweep --force --keep wip/experiment
#
# NOTES
#   The same checks drive the prune-it skill in rootiest-ai, so an agent
#   and this function make the same decisions.
function git-sweep --description 'Sync the default branch and delete merged or orphaned branches'
    __fish_help_header (status current-function) $argv; and return 0

    argparse n/dry-run f/force l/local-only 'r/remote=' 'k/keep=+' -- $argv
    or return
    __fish_no_args (status current-function) $argv; or return

    __fish_palette

    if not git rev-parse --is-inside-work-tree >/dev/null 2>&1
        echo "$c_err""git-sweep: not inside a git work tree$c_reset" >&2
        return 2
    end

    set -l remote origin
    set -q _flag_remote; and set remote $_flag_remote
    set -l do_remote 1
    set -q _flag_local_only; and set do_remote 0

    #   ──────── Fetch ────────
    set -l has_remote 0
    if git remote get-url $remote >/dev/null 2>&1
        set has_remote 1
        echo "$c_dim""Fetching and pruning '$remote'...$c_reset"
        if not git fetch --prune --quiet $remote
            echo "$c_warn""git-sweep: fetch from '$remote' failed; using the last fetched state, local branches only$c_reset" >&2
            set do_remote 0
        end
    else
        echo "$c_dim""No remote '$remote'; cleaning local branches only.$c_reset"
        set do_remote 0
    end
    git worktree prune

    #   ──────── Default branch and comparison base ────────
    set -l default
    set -l head_ref (git symbolic-ref --quiet --short refs/remotes/$remote/HEAD 2>/dev/null)
    if test $has_remote -eq 1; and test -n "$head_ref"
        set default (string sub -s (math (string length -- $remote) + 2) -- $head_ref)
    else
        for b in main master
            if git show-ref --verify --quiet refs/remotes/$remote/$b
                or git show-ref --verify --quiet refs/heads/$b
                set default $b
                break
            end
        end
    end
    if test -z "$default"
        echo "$c_err""git-sweep: cannot determine the default branch$c_reset" >&2
        return 2
    end

    set -l base refs/heads/$default
    if test $has_remote -eq 1; and git show-ref --verify --quiet refs/remotes/$remote/$default
        set base refs/remotes/$remote/$default
    end
    echo "$c_dim""Default branch: $default (comparing against "(string replace -- refs/remotes/ '' $base)")$c_reset"

    set -l protect $default main master develop dev trunk staging production gh-pages $_flag_keep
    set -l current (git branch --show-current)
    set -l toplevel (git rev-parse --show-toplevel)

    #   ──────── Plan: remote branches ────────
    set -l remote_del
    set -l open_heads
    if test $do_remote -eq 1
        set -l candidates
        set -l reasons
        for ref in (git for-each-ref --format='%(refname)' refs/remotes/$remote/)
            set -l name (string replace -- refs/remotes/$remote/ '' $ref)
            test "$name" = HEAD; and continue
            contains -- $name $protect; and continue
            string match -q 'release/*' -- $name; and continue
            set -l reason (_git_sweep_merged $ref $base)
            or continue
            set -a candidates $name
            set -a reasons $reason
        end

        if set -q candidates[1]
            echo "$c_head""Remote branches on '$remote':$c_reset"
            set -l heads (_git_sweep_open_prs $remote)
            if test $status -eq 0
                for i in (seq (count $candidates))
                    if contains -- $candidates[$i] $heads
                        set -a open_heads refs/remotes/$remote/$candidates[$i]
                        echo "  $c_ok""keep$c_reset    $remote/$candidates[$i]  $c_dim(head of an open PR)$c_reset"
                    else
                        set -a remote_del $candidates[$i]
                        echo "  $c_err""delete$c_reset  $remote/$candidates[$i]  $c_dim($reasons[$i])$c_reset"
                    end
                end
            else
                echo "  $c_warn""Could not list open PRs on '$remote'; not deleting these merged remote branches:$c_reset"
                printf '            %s\n' $remote/$candidates
            end
        end
    end

    #   ──────── Plan: local branches ────────
    set -l local_del
    set -l kept_unmerged
    # Plan lines are collected so the section header prints only when
    # there is something under it.
    set -l local_plan
    # \x1f separates fields: a tab would collapse an empty upstream column.
    for row in (git for-each-ref --format='%(refname)%1f%(upstream)%1f%(upstream:track)%1f%(worktreepath)' refs/heads/)
        set -l f (string split \x1f -- $row)
        set -l name (string replace -- refs/heads/ '' $f[1])
        set -l upstream $f[2]
        set -l wtpath $f[4]

        contains -- $name $protect; and continue
        string match -q 'release/*' -- $name; and continue
        if test -n "$upstream"; and contains -- $upstream $open_heads
            set -a local_plan "  $c_ok""keep$c_reset    $name  $c_dim(tracks the head of an open PR)$c_reset"
            continue
        end
        if test -n "$wtpath"; and test "$wtpath" != "$toplevel"
            set -a local_plan "  $c_ok""keep$c_reset    $name  $c_dim(checked out in worktree $wtpath)$c_reset"
            continue
        end
        # Created and never moved: new work, not merged work. Only for
        # branches with no upstream, so a checked-out copy of someone
        # else's remote branch is still cleaned up.
        if test -z "$upstream"
            set -l entries (git reflog show --format=%gs refs/heads/$name -- 2>/dev/null)
            if set -q entries[1]; and not string match -qv 'branch: Created from*' -- $entries
                continue
            end
        end

        set -l gone 0
        test "$f[3]" = "[gone]"; and set gone 1
        set -l reason (_git_sweep_merged $f[1] $base)
        if test $status -eq 0
            test $gone -eq 1; and set reason "$reason, upstream gone"
            set -a local_del $name
            set -a local_plan "  $c_err""delete$c_reset  $name  $c_dim($reason)$c_reset"
        else if test $gone -eq 1
            if set -q _flag_force
                set -a local_del $name
                set -a local_plan "  $c_err""delete$c_reset  $name  $c_dim(upstream gone, UNMERGED commits, --force)$c_reset"
            else
                set -a kept_unmerged $name
                set -a local_plan "  $c_warn""keep$c_reset    $name  $c_dim(upstream gone but has unmerged commits; use --force)$c_reset"
            end
        end
    end

    if set -q local_plan[1]
        echo "$c_head""Local branches:$c_reset"
        printf '%s\n' $local_plan
    end

    if not set -q remote_del[1]; and not set -q local_del[1]
        echo "$c_ok""Nothing to delete.$c_reset"
    end
    if set -q _flag_dry_run
        echo "$c_dim""Dry run: no changes made.$c_reset"
        return 0
    end

    #   ──────── Execute ────────
    # Leave the current branch first if it is going away.
    if contains -- $current $local_del
        set -l dirty (git status --porcelain --untracked-files=no)
        if set -q dirty[1]
            echo "$c_warn""Keeping current branch '$current': tracked files have uncommitted changes.$c_reset" >&2
            set -e local_del[(contains -i -- $current $local_del)]
        else if git show-ref --verify --quiet refs/heads/$default
            git switch --quiet $default; and set current $default
        else
            git switch --quiet --track -c $default $base; and set current $default
        end
    end

    # Fast-forward the local default branch. A local fetch with no '+'
    # refuses non-fast-forward updates and branches checked out elsewhere.
    if test $base != refs/heads/$default; and git show-ref --verify --quiet refs/heads/$default
        echo "$c_dim""Fast-forwarding '$default'...$c_reset"
        if test "$current" = "$default"
            git merge --ff-only --quiet $base
            or echo "$c_warn""  Could not fast-forward '$default'; left as is.$c_reset" >&2
        else
            git fetch --quiet . $base:refs/heads/$default 2>/dev/null
            or echo "$c_warn""  Could not fast-forward '$default'; left as is.$c_reset" >&2
        end
    end

    set -l failed 0
    if set -q remote_del[1]
        echo "$c_head""Deleting merged branches on '$remote':$c_reset"
        printf '  %s\n' $remote_del
        git push --quiet $remote --delete $remote_del
        or set failed 1
    end
    if set -q local_del[1]
        echo "$c_head""Deleting local branches:$c_reset"
        for name in $local_del
            git branch -D $name
            or set failed 1
        end
        echo "$c_dim""Restore a deleted local branch with: git branch <name> <sha>$c_reset"
    end
    if set -q kept_unmerged[1]
        echo "$c_warn""Kept "(count $kept_unmerged)" gone branch(es) with unmerged commits; rerun with --force to delete them.$c_reset"
    end

    test $failed -eq 0
end
