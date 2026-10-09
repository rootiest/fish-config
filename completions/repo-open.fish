# Copyright (C) 2026 Rootiest
# SPDX-License-Identifier: AGPL-3.0-or-later
#
# Completions for repo-open.
#
# Takes no positional arguments (argparse -X 0), so file completion is off.

complete -c repo-open -f
complete -c repo-open -s h -l help -d 'Show help message'
complete -c repo-open -s p -l print -d 'Print the resolved URL instead of opening it'
complete -c repo-open -s r -l root -d 'Link to the repo root, not the current sub-directory'
