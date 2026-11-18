# Copyright (C) 2026 Rootiest
# SPDX-License-Identifier: AGPL-3.0-or-later
#
# Completions for dockup.
#
# One directory holding a docker-compose.yml (default: the current one).

complete -c dockup -s h -l help -d 'Show help'
complete -c dockup -x -a '(__fish_complete_directories)'
