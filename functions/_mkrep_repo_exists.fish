# Copyright (C) 2026 Rootiest
# SPDX-License-Identifier: AGPL-3.0-or-later

# DEPENDENCIES
#   gh, glab, tea
#
# SYNOPSIS
#   _mkrep_repo_exists <type> <user> <name>
#
# DESCRIPTION
#   Checks whether <user>/<name> already exists on the given server, for
#   mkrep's --server and --check-existing flows. Each host CLI is already
#   authenticated (gh/glab/tea login), so this shells out to its own
#   repo-lookup command rather than querying an API directly.
#
# ARGUMENTS
#   type   gitea, gitlab, or github
#   user   Account/namespace to check under
#   name   Repo name
#
# EXIT STATUS
#   0  repository exists
#   1  repository does not exist, the check tool is missing, or type is
#      invalid
function _mkrep_repo_exists --argument-names type user name
    switch $type
        case github
            type -q gh; or return 1
            gh repo view "$user/$name" >/dev/null 2>&1
        case gitlab
            type -q glab; or return 1
            glab repo view "$user/$name" >/dev/null 2>&1
        case gitea
            type -q tea; or return 1
            tea repos "$user/$name" >/dev/null 2>&1
        case '*'
            return 1
    end
end
