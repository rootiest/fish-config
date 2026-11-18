# Copyright (C) 2026 Rootiest
# SPDX-License-Identifier: AGPL-3.0-or-later
#
# Completions for bkg.
#
# A command and its arguments, run detached under nohup.

complete -c bkg -n __fish_is_first_token -s h -l help -d 'Show help'
complete -c bkg -x -a '(__fish_complete_subcommand)'
