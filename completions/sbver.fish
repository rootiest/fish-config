# Copyright (C) 2026 Rootiest
# SPDX-License-Identifier: AGPL-3.0-or-later
#
# Completions for sbver.
#
# At most one flag; there are no positionals.

complete -c sbver -f
complete -c sbver -n 'test (count (commandline -opc)) -eq 1' -s h -l help -d 'Show help'
complete -c sbver -n 'test (count (commandline -opc)) -eq 1' -l brief -d 'Print only the pass/fail summary'
