# Copyright (C) 2026 Rootiest
# SPDX-License-Identifier: AGPL-3.0-or-later
#
# Completions for logs.

complete -c logs -f
complete -c logs -s h -l help -d 'Show help message'
complete -c logs -s c -l category -x -a 'scrollback\t"Terminal scrollback logs" paru\t"paru build logs" yay\t"yay build logs"' -d 'Limit to one log category'
