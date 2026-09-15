# Copyright (C) 2026 Rootiest
# SPDX-License-Identifier: AGPL-3.0-or-later

# SYNOPSIS
#   _mkrep_remote_url <type> <user> <name> <url>
#
# DESCRIPTION
#   Builds the clone URL for a repo on <type>, for mkrep's --server flow:
#   linking to a repo that already exists, and reporting the URL of one it
#   just created. <url> is the resolved server base (from --server/$GIT_SERVER
#   plus $GITEA_URL/$GITEA_HOST/$GITLAB_URL/$GITLAB_HOST) and is unused for
#   github, which always resolves to github.com.
#
# ARGUMENTS
#   type   gitea, gitlab, or github
#   user   Account/namespace the repo lives under
#   name   Repo name
#   url    Server base URL (required for gitea/gitlab)
#
# RETURNS
#   The clone URL, on stdout
#
# EXIT STATUS
#   0  URL built
#   1  unrecognized type, or gitea/gitlab given with no url
function _mkrep_remote_url --argument-names type user name url
    switch $type
        case github
            echo "https://github.com/$user/$name.git"
        case gitlab gitea
            test -n "$url"; or return 1
            echo "$url/$user/$name.git"
        case '*'
            return 1
    end
end
