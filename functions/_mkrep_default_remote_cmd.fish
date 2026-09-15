# Copyright (C) 2026 Rootiest
# SPDX-License-Identifier: AGPL-3.0-or-later

# SYNOPSIS
#   _mkrep_default_remote_cmd <type>
#
# DESCRIPTION
#   Prints the default remote-create command template for <type>, used by
#   mkrep's --server flow when $MKREP_REMOTE_CMD is unset. Same {name},
#   {user}, {server} placeholders as --new-remote.
#
# ARGUMENTS
#   type   gitea, gitlab, or github
#
# RETURNS
#   The template string, on stdout
#
# EXIT STATUS
#   0  known type
#   1  unrecognized type
function _mkrep_default_remote_cmd --argument-names type
    switch $type
        case github
            echo 'gh repo create {name} --private --source=. --remote=origin --push'
        case gitlab
            echo 'glab repo create {name} --private --skipGitInit && git remote add origin {server}/{user}/{name}.git && git push -u origin HEAD'
        case gitea
            echo 'tea repos create --name {name} --private && git remote add origin {server}/{user}/{name}.git && git push -u origin HEAD'
        case '*'
            return 1
    end
end
