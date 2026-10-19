# Copyright (C) 2026 Rootiest
# SPDX-License-Identifier: AGPL-3.0-or-later
#
# Completions for git-clean (deprecated; see git-sweep).
#
# Takes no positional arguments, so file completion is off.

complete -c git-clean -f
complete -c git-clean -s h -l help -d 'Show help message'
complete -c git-clean -s f -l force -d 'Also delete gone branches with unmerged commits'
