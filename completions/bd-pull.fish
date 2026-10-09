# Copyright (C) 2026 Rootiest
# SPDX-License-Identifier: AGPL-3.0-or-later
#
# Completions for bd-pull.
#
# The single positional is a Gitea repository path in owner/name form, which
# nothing local can complete, so file completion is off.

complete -c bd-pull -f
complete -c bd-pull -s h -l help -d 'Show help message'
complete -c bd-pull -l push -d 'Push the .beads/issues.jsonl commit (default: do not push)'
