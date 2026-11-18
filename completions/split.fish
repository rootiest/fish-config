# Copyright (C) 2026 Rootiest
# SPDX-License-Identifier: AGPL-3.0-or-later
#
# Completions for split.
#
# An optional direction flag, then a command (and its arguments) to run in
# the new split. -h here means horizontal; help is --help only.

complete -c split -f
complete -c split -n 'test (count (commandline -opc)) -eq 1' -l help -d 'Show help'
complete -c split -n 'test (count (commandline -opc)) -eq 1' -s h -l horizontal -d 'Split below (default)'
complete -c split -n 'test (count (commandline -opc)) -eq 1' -s v -l vertical -d 'Split to the right'
complete -c split -x -a '(__fish_complete_subcommand)'
