# Copyright (C) 2026 Rootiest
# SPDX-License-Identifier: AGPL-3.0-or-later
#
# Completions for config-settings.
#
# No positionals, so file completion is off.

complete -c config-settings -f
complete -c config-settings -s h -l help -d 'Show help message'
complete -c config-settings -s s -l style -x -a 'color\tDefault mono\t"No colour, reverse-video selection" contrast\t"Bold, no dim text"' -d 'Display style'
