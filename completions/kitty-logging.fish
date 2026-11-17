# Copyright (C) 2026 Rootiest
# SPDX-License-Identifier: AGPL-3.0-or-later
#
# Completions for kitty-logging.
#
# One subcommand and nothing after it.

set -l subcmds install uninstall status dismiss help

complete -c kitty-logging -f
complete -c kitty-logging -s h -l help -d 'Show help'

complete -c kitty-logging -n "not __fish_seen_subcommand_from $subcmds" \
    -a install -d 'Copy the watcher and wire it into kitty.conf'
complete -c kitty-logging -n "not __fish_seen_subcommand_from $subcmds" \
    -a uninstall -d 'Remove the managed block and the watcher file'
complete -c kitty-logging -n "not __fish_seen_subcommand_from $subcmds" \
    -a status -d 'Show wiring, watcher version, and C5 state'
complete -c kitty-logging -n "not __fish_seen_subcommand_from $subcmds" \
    -a dismiss -d 'Stop the per-session reminder'
complete -c kitty-logging -n "not __fish_seen_subcommand_from $subcmds" \
    -a help -d 'Show help'
