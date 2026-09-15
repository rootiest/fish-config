# Copyright (C) 2026 Rootiest
# SPDX-License-Identifier: AGPL-3.0-or-later

# SYNOPSIS
#   _mkrep_default_remote_cmd <type>
#
# DESCRIPTION
#   Prints the default remote-create command template for <type>, used by
#   mkrep's --server flow when $MKREP_REMOTE_CMD is unset. Same {name},
#   {user}, {server} placeholders as --new-remote. gitlab/gitea guard
#   their final push on HEAD actually resolving to a commit -- mkrep only
#   ever runs `git init`, so a fresh call has no commit yet, and
#   `git push -u origin HEAD` errors on an unborn HEAD regardless of the
#   remote. Skipping the push there is silent success, not a swallowed
#   failure: once a commit exists, a real push failure still propagates.
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
            echo 'glab repo create {name} --private --skipGitInit && git remote add origin {server}/{user}/{name}.git && if git rev-parse --verify -q HEAD >/dev/null 2>&1; git push -u origin HEAD; end'
        case gitea
            echo 'tea repos create --name {name} --private && git remote add origin {server}/{user}/{name}.git && if git rev-parse --verify -q HEAD >/dev/null 2>&1; git push -u origin HEAD; end'
        case '*'
            return 1
    end
end
