# Copyright (C) 2026 Rootiest
# SPDX-License-Identifier: AGPL-3.0-or-later
#
# Completions for branch.
#
# Local branches only: a name with no local branch is created from HEAD, so
# offering remote branches would suggest a checkout that branch does not do.

complete -c branch -f
complete -c branch -n __fish_is_first_token -s h -l help -d 'Show help'
complete -c branch -n __fish_is_first_token \
    -a "(git for-each-ref --format='%(refname:short)' refs/heads/ 2>/dev/null)" \
    -d 'Local branch'
