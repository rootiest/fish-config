# Copyright (C) 2026 Rootiest
# SPDX-License-Identifier: AGPL-3.0-or-later
#
# Completions for detach.
#
# A command and its arguments, run detached under nohup. detach rejects any
# option it does not know, wherever it appears, so the command's own options
# are not offered: only its name, then files.

complete -c detach -n __fish_is_first_token -s h -l help -d 'Show help'
complete -c detach -n __fish_is_first_token -l version -d 'Show version'
complete -c detach -n __fish_is_first_token -x -a '(__fish_complete_command)'
