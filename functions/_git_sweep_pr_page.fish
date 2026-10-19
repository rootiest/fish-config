# Copyright (C) 2026 Rootiest
# SPDX-License-Identifier: AGPL-3.0-or-later

# DEPENDENCIES
#   _git_sweep_token, curl, gh, glab, jq, python3, tea
#
# CLASSIFICATION
#   network
#
# SYNOPSIS
#   _git_sweep_pr_page <method> <forge> <host> <path> <page>
#
# DESCRIPTION
#   Fetches one page of open pull (merge) requests for repository <path> on
#   <host>, and prints the head branch name of each. <forge> is github,
#   gitea or gitlab. <method> picks the transport:
#
#     cli    the forge's own CLI (gh, tea or glab), scoped to <host>
#     token  curl with a token from _git_sweep_token for <host>
#     anon   curl with no credentials (works for public repositories)
#
#   Fails when the method is unavailable (tool or token missing) or the
#   response is not a JSON array, which is also what a request to the wrong
#   forge's API returns: an HTML page, a redirect, or an error object.
#   Redirects are never followed, so a token is never sent to another host.
#   The token travels on curl's stdin, never on its command line.
#
#   JSON is parsed with jq, or python3 when jq is missing. gh needs neither.
#
# EXIT STATUS
#   0  The page was fetched (it may be empty)
#   1  Method unavailable, request failed, or the response was not a list
#
# RETURNS
#   Head branch names, one per line. For Gitea and GitHub both head.ref and
#   head.label are printed, since Gitea rewrites ref to refs/pull/N/head
#   once a branch is deleted; extra names only make the caller keep more.
#
# EXAMPLE
#   _git_sweep_pr_page anon gitea git.rootiest.dev rootiest/fish-config 1
function _git_sweep_pr_page --argument-names method forge host path page
    set -l q
    set -l api
    set -l auth
    switch $forge
        case github
            set q "repos/$path/pulls?state=open&per_page=100&page=$page"
            set api https://api.github.com
            test "$host" = github.com; or set api https://$host/api/v3
            set auth 'Authorization: Bearer'
        case gitea
            set q "repos/$path/pulls?state=open&limit=50&page=$page"
            set api https://$host/api/v1
            set auth 'Authorization: token'
        case gitlab
            set q "projects/"(string replace -a / %2F -- $path)"/merge_requests?state=opened&per_page=100&page=$page"
            set api https://$host/api/v4
            set auth 'PRIVATE-TOKEN:'
        case '*'
            return 1
    end

    set -l body
    switch $method
        case cli
            switch $forge
                case github
                    # gh filters with its built-in jq, so no parser is needed.
                    type -q gh; or return 1
                    gh api --hostname $host $q \
                        -q 'if type == "array" then .[].head | .ref, (.label // "" | sub("^[^:]*:"; "")) else error("not a list") end' </dev/null 2>/dev/null
                    or return 1
                    return 0
                case gitea
                    type -q tea; or return 1
                    # Use the login for this host, not tea's default login.
                    set -l login
                    for row in (tea login list -o tsv </dev/null 2>/dev/null)
                        set -l f (string split \t -- $row)
                        if test "$(_git_sweep_host $f[2])" = "$host"
                            set login $f[1]
                            break
                        end
                    end
                    test -n "$login"; or return 1
                    set body (tea api --login $login "/$q" </dev/null 2>/dev/null)
                    or return 1
                case gitlab
                    type -q glab; or return 1
                    set body (glab api --hostname $host $q </dev/null 2>/dev/null)
                    or return 1
            end
        case token anon
            type -q curl; or return 1
            set -l header
            if test $method = token
                set -l tok (_git_sweep_token $forge $host)
                or return 1
                set header "$auth $tok"
            end
            # -H @- reads the header from stdin; an empty stdin adds none.
            set body (printf '%s' $header | curl -fsS --connect-timeout 5 --max-time 20 \
                -H 'Accept: application/json' -H @- "$api/$q" 2>/dev/null)
            or return 1
        case '*'
            return 1
    end

    # jq accepts empty input and prints nothing, which would read as "no open
    # PRs". An empty body (e.g. a redirect from the wrong forge) is a failure.
    string match -qr '\S' -- $body; or return 1

    if type -q jq
        set -l filter '.[].head | .ref, (.label // "" | sub("^[^:]*:"; ""))'
        test $forge = gitlab; and set filter '.[].source_branch'
        printf '%s\n' $body | jq -r "if type == \"array\" then $filter else error(\"not a list\") end" 2>/dev/null
        or return 1
    else if type -q python3
        printf '%s\n' $body | python3 -c '
import json, sys
data = json.load(sys.stdin)
if not isinstance(data, list):
    sys.exit(1)
for pr in data:
    if sys.argv[1] == "gitlab":
        print(pr.get("source_branch") or "")
    else:
        head = pr.get("head") or {}
        print(head.get("ref") or "")
        print((head.get("label") or "").split(":")[-1])
' $forge 2>/dev/null
        or return 1
    else
        return 1
    end
    return 0
end
