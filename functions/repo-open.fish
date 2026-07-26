# Copyright (C) 2026 Rootiest
# SPDX-License-Identifier: AGPL-3.0-or-later

# CATEGORY
#   14-miscellaneous
#
# SYNOPSIS
#   repo-open [-p|--print] [-r|--root]
#   repo-open --help
#
# DESCRIPTION
#   Opens the web page for the current repository's `origin` remote in a
#   browser (via open-url). Deep-links to the current branch when it exists
#   on the remote, falling back to the remote's default branch (main/master)
#   otherwise, and to the current sub-directory when invoked below the repo
#   root.
#
#   The remote URL is normalized from both HTTPS and SSH/scp forms
#   (git@host:owner/repo.git, ssh://…, https://…). The web path layout is
#   provider-specific; the provider is resolved in this order:
#
#     1. git config browse.provider   (per-repo or --global override)
#     2. Hostname heuristic           (github / gitlab / gitea / bitbucket;
#                                       codeberg → gitea)
#     3. Default: github-style layout
#
#   For a self-hosted host the heuristic can't classify (e.g. a Gitea or
#   GitLab instance on a custom domain), set the provider once:
#
#     git config browse.provider gitea
#
# ARGUMENTS
#   -p, --print  Print the resolved URL instead of opening it
#   -r, --root   Ignore the current sub-directory; link to the repo root
#   -h, --help   Print usage and exit
#
# RETURNS
#   0  URL opened (or printed)
#   1  Not a git repo, no origin remote, or browser launch failed
#
# EXAMPLE
#   repo-open              # open current branch (+ subdir) in browser
#   repo-open --print      # just print the URL
#   repo-open --root       # repo home page for the current branch
#   repo-open
#   repo-open --print
#   repo-open --root
#
# NOTES
#   Typo abbreviation: open-repo (expands to repo-open on space/enter).
function repo-open --description 'Open the origin remote of the current repo in a browser'
    argparse -X 0 h/help p/print r/root -- $argv
    or return 1

    if set -q _flag_help
        echo "Usage: repo-open [-p|--print] [-r|--root]"
        echo "Open the origin remote's web page for the current repo,"
        echo "deep-linking to the current branch and sub-directory."
        echo
        echo "  -p, --print  Print the URL instead of opening it"
        echo "  -r, --root   Link to the repo root, ignoring the current sub-directory"
        echo "  -h, --help   Show this help"
        return 0
    end

    if not git rev-parse --is-inside-work-tree >/dev/null 2>&1
        set_color red
        echo "error: not inside a git repository" >&2
        set_color normal
        return 1
    end

    set -l remote (git remote get-url origin 2>/dev/null)
    if test -z "$remote"
        set_color red
        echo "error: no 'origin' remote configured" >&2
        set_color normal
        return 1
    end

    # ── Normalize remote → host + owner/repo path ────────────────
    set -l had_scheme 0
    if string match -qr '://' -- $remote
        set had_scheme 1
    end
    set -l u (string replace -r '^[a-z0-9]+://' '' -- $remote) # strip scheme
    set u (string replace -r '^[^@/]+@' '' -- $u)             # strip user@
    set u (string replace -r '\.git$' '' -- $u)               # strip .git
    if test $had_scheme -eq 0
        set u (string replace ':' '/' -- $u)      # scp: first colon → path sep
    else
        set u (string replace -r ':[0-9]+/' '/' -- $u)  # url: drop :port
    end

    set -l parts (string split -m1 '/' -- $u)
    set -l host $parts[1]
    set -l repo_path $parts[2]
    if test -z "$host"; or test -z "$repo_path"
        set_color red
        echo "error: could not parse origin remote: $remote" >&2
        set_color normal
        return 1
    end
    set -l base "https://$host/$repo_path"

    # ── Resolve provider (config → hostname → default) ───────────
    set -l provider (git config --get browse.provider 2>/dev/null)
    if test -z "$provider"
        switch $host
            case 'github.com' 'www.github.com'
                set provider github
            case '*gitlab*'
                set provider gitlab
            case '*gitea*' 'codeberg.org'
                set provider gitea
            case '*bitbucket*'
                set provider bitbucket
            case '*'
                set provider github # sensible default; override via browse.provider
        end
    end

    # ── Determine the default branch (for the "on default" check) ─
    set -l default_branch (git symbolic-ref --quiet --short refs/remotes/origin/HEAD 2>/dev/null \
        | string replace -r '^origin/' '')
    if test -z "$default_branch"
        for b in main master
            if git rev-parse --verify --quiet refs/remotes/origin/$b >/dev/null 2>&1
                set default_branch $b
                break
            end
        end
    end
    test -z "$default_branch"; and set default_branch main

    # ── Determine the branch to link to ──────────────────────────
    set -l branch (git symbolic-ref --quiet --short HEAD 2>/dev/null)
    if test -n "$branch"
        # Prefer the local remote-tracking ref (offline, fast); fall back to a
        # networked ls-remote before giving up on the current branch.
        if not git rev-parse --verify --quiet refs/remotes/origin/$branch >/dev/null 2>&1
            if not git ls-remote --exit-code --heads origin $branch >/dev/null 2>&1
                set branch $default_branch
            end
        end
    else
        set branch $default_branch # detached HEAD
    end

    # ── Sub-directory relative to repo root ──────────────────────
    set -l prefix ""
    if not set -q _flag_root
        set prefix (git rev-parse --show-prefix 2>/dev/null | string trim -r -c /)
    end

    # ── Assemble the provider-specific URL ───────────────────────
    set -l seg
    switch $provider
        case gitlab
            set seg "/-/tree/$branch"
        case gitea
            set seg "/src/branch/$branch"
        case bitbucket
            set seg "/src/$branch"
        case '*' # github and default
            set seg "/tree/$branch"
    end

    set -l url $base
    if test -n "$prefix"
        set url "$base$seg/$prefix"
    else if test "$branch" != "$default_branch"
        set url "$base$seg"
    end

    if set -q _flag_print
        echo $url
        return 0
    end

    open-url $url
    return $status
end
