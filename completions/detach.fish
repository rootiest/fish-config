# Copyright (C) 2026 Rootiest
# SPDX-License-Identifier: AGPL-3.0-or-later
#
# Completions for detach.
#
# detach's own options, then a command and its arguments, run detached under
# nohup. Everything from the command's name on is the command's, so its own
# completions take over there.

complete -c detach -n __fish_is_first_token -s h -l help -d 'Show help'
complete -c detach -n __fish_is_first_token -l version -d 'Show version'
complete -c detach -x -a '(__fish_complete_subcommand)'
