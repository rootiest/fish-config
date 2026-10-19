# Copyright (C) 2026 Rootiest
# SPDX-License-Identifier: AGPL-3.0-or-later

# DEPENDENCIES
#   _git_sweep_host
#
# SYNOPSIS
#   _git_sweep_token <forge> <host>
#
# DESCRIPTION
#   Prints the first API token in the environment that belongs to <host> on
#   <forge> (github, gitea or gitlab). A token is only ever handed out for
#   the host it is bound to, so a repository hosted on someone else's
#   server never receives your token:
#
#     github  GH_TOKEN, GITHUB_TOKEN, GITHUB_PERSONAL_ACCESS_TOKEN are bound
#             to github.com. GH_ENTERPRISE_TOKEN, GITHUB_ENTERPRISE_TOKEN
#             are bound to $GH_HOST.
#     gitea   GITEA_TOKEN, GITEA_ACCESS_TOKEN, FORGEJO_TOKEN are bound to
#             the host in $GITEA_HOST, $GITEA_URL, $GITEA_SERVER_URL or
#             $FORGEJO_HOST. With none of those set they are never used:
#             Gitea has no default host to assume.
#     gitlab  GITLAB_TOKEN, GITLAB_PRIVATE_TOKEN, GITLAB_ACCESS_TOKEN are
#             bound to the host in $GITLAB_HOST, $GITLAB_URI or
#             $GITLAB_URL, or to gitlab.com when none is set.
#
# EXIT STATUS
#   0  A token was found
#   1  No token for this forge and host
#
# RETURNS
#   The token, on stdout. Callers must never echo it.
#
# EXAMPLE
#   set -l tok (_git_sweep_token gitea git.rootiest.dev)
function _git_sweep_token --argument-names forge host
    set -l tokens
    set -l bound
    switch $forge
        case github
            if test "$host" = github.com
                set tokens GH_TOKEN GITHUB_TOKEN GITHUB_PERSONAL_ACCESS_TOKEN
                set bound github.com
            else
                set tokens GH_ENTERPRISE_TOKEN GITHUB_ENTERPRISE_TOKEN
                set bound GH_HOST
            end
        case gitea
            set tokens GITEA_TOKEN GITEA_ACCESS_TOKEN FORGEJO_TOKEN
            set bound GITEA_HOST GITEA_URL GITEA_SERVER_URL FORGEJO_HOST
        case gitlab
            set tokens GITLAB_TOKEN GITLAB_PRIVATE_TOKEN GITLAB_ACCESS_TOKEN
            set bound GITLAB_HOST GITLAB_URI GITLAB_URL
            if not set -q GITLAB_HOST; and not set -q GITLAB_URI; and not set -q GITLAB_URL
                set bound gitlab.com
            end
        case '*'
            return 1
    end

    # `bound` holds variable names, except the literal default hosts.
    set -l match 0
    for b in $bound
        set -l value $b
        string match -q '*.*' -- $b; or set value $$b
        test -n "$value"; or continue
        if test "$(_git_sweep_host $value)" = "$host"
            set match 1
            break
        end
    end
    test $match -eq 1; or return 1

    for t in $tokens
        if test -n "$$t"
            printf '%s\n' $$t
            return 0
        end
    end
    return 1
end
