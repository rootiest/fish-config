# Copyright (C) 2026 Rootiest
# SPDX-License-Identifier: AGPL-3.0-or-later
#
# Completions for git-sweep.
#
# Takes no positional arguments, so file completion is off.

complete -c git-sweep -f
complete -c git-sweep -s h -l help -d 'Show help message'
complete -c git-sweep -s n -l dry-run -d 'Print the plan; change nothing but the fetch'
complete -c git-sweep -s f -l force -d 'Also delete gone branches with unmerged commits'
complete -c git-sweep -s l -l local-only -d 'Never delete remote branches'
complete -c git-sweep -s r -l remote -x -a '(git remote 2>/dev/null)' -d 'Remote to sync and prune'
complete -c git-sweep -s k -l keep -x -a '(git for-each-ref --format="%(refname:short)" refs/heads/ 2>/dev/null)' -d 'Never delete this branch'
