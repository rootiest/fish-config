# Copyright (C) 2026 Rootiest
# SPDX-License-Identifier: AGPL-3.0-or-later
#
# Completions for mkcd.
#
# One directory, new or existing.

complete -c mkcd -s h -l help -d 'Show help'
complete -c mkcd -s s -l silent -d 'Do not print the created tree'
complete -c mkcd -x -a '(__fish_complete_directories)'
