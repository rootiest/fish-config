# Copyright (C) 2026 Rootiest
# SPDX-License-Identifier: AGPL-3.0-or-later
#
# Completions for wake-lock.
#
# A command and its arguments, run under systemd-inhibit.

complete -c wake-lock -n __fish_is_first_token -s h -l help -d 'Show help'
complete -c wake-lock -x -a '(__fish_complete_subcommand)'
