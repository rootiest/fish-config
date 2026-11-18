# Copyright (C) 2026 Rootiest
# SPDX-License-Identifier: AGPL-3.0-or-later
#
# Completions for config-update.
#
# Flags only; there are no positionals.

complete -c config-update -f
complete -c config-update -s h -l help -d 'Show help'
complete -c config-update -s f -l force -d 'Stash local changes, pull, then restore them'
complete -c config-update -s n -l dry-run -d 'Check for updates without applying them'
