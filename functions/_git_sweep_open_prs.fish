# Copyright (C) 2026 Rootiest
# SPDX-License-Identifier: AGPL-3.0-or-later

# DEPENDENCIES
#   _git_sweep_host, _git_sweep_pr_page, ssh
#
# CLASSIFICATION
#   network, bypasses-shadow(ssh)
#
# SYNOPSIS
#   _git_sweep_open_prs <remote>
#
# DESCRIPTION
#   Prints the head branch of every open pull (merge) request on <remote>'s
#   repository, trying every way it knows until one works, so it needs no
#   particular tool or token:
#
#     1. The forge is guessed from the host only to order the attempts:
#        github first for a host containing "github", gitlab first for
#        "gitlab", otherwise gitea, then gitlab, then GitHub Enterprise.
#        github.com and gitlab.com are only tried as themselves. A wrong
#        guess costs one failed request, so self-hosted forges on custom
#        domains need no configuration.
#     2. For each forge: its CLI, then curl with a token bound to the host,
#        then anonymous curl (public repositories).
#     3. Results are paged until an empty page. A listing that has not
#        ended after 20 pages is treated as a failure, so an API that
#        ignores paging cannot loop or truncate silently.
#
#   For an ssh remote using a Host alias from ~/.ssh/config, the real host
#   is resolved with ssh -G.
#
# EXIT STATUS
#   0  The full list was fetched (it may be empty)
#   1  No method could list open PRs; the caller must not assume none exist
#
# RETURNS
#   Head branch names, one per line.
#
# EXAMPLE
#   _git_sweep_open_prs origin
function _git_sweep_open_prs --argument-names remote
    set -l url (git remote get-url $remote 2>/dev/null)
    or return 1
    set -l host (_git_sweep_host $url)
    or return 1

    # Repository path: everything after the host (and port), minus .git.
    set -l path (string replace -r '^[a-zA-Z][a-zA-Z0-9+.-]*://[^/]*/' '' -- $url)
    test "$path" = "$url"; and set path (string replace -r '^[^:]*:' '' -- $url)
    set path (string replace -r '\.git$' '' -- (string trim -c / -- $path))
    test -n "$path"; or return 1

    # ssh remotes may name a Host alias; ask ssh for the real host name.
    if not string match -qr '^https?://' -- $url; and type -q ssh
        set -l real (command ssh -G $host 2>/dev/null | string replace -rf '^hostname ' '')
        test -n "$real[1]"; and set host (string lower -- $real[1])
    end

    set -l forges gitea gitlab github
    switch $host
        case github.com
            set forges github
        case gitlab.com
            set forges gitlab
        case '*github*'
            set forges github gitea gitlab
        case '*gitlab*'
            set forges gitlab gitea github
    end

    for forge in $forges
        for method in cli token anon
            set -l heads
            set -l complete 0
            for page in (seq 20)
                set -l names (_git_sweep_pr_page $method $forge $host $path $page)
                or break
                if not set -q names[1]
                    set complete 1
                    break
                end
                set -a heads $names
            end
            if test $complete -eq 1
                set -q heads[1]; and printf '%s\n' $heads
                return 0
            end
        end
    end
    return 1
end
