# Copyright (C) 2026 Rootiest
# SPDX-License-Identifier: AGPL-3.0-or-later
#
# Completions for gi.
#
# The positionals are gitignore.io target names (python, c++, neovim, ...).
# Completing them would mean a network round-trip to the API on every Tab, so
# file completion is simply off; `gi --list` shows the supported targets.

complete -c gi -f
complete -c gi -s h -l help -d 'Show help message'
complete -c gi -s d -l description -d 'Show the function description'
complete -c gi -s l -l list -d 'List all supported targets from the API'
complete -c gi -s b -l boilerplate -d 'Append boilerplate (implied by --custom)'
complete -c gi -s p -l prompt -d 'Prompt for patterns and append them to .gitignore'
complete -c gi -s o -l stdout -d 'Print generated content to stdout instead of .gitignore'
complete -c gi -s s -l silent -d 'Suppress progress output (errors and prompts still show)'
complete -c gi -s f -l force -d 'Bypass prompts, proceeding with the default action'
complete -c gi -s c -l custom -r -F -d 'Use this file as the boilerplate template'
