# Copyright (C) 2026 Rootiest
# SPDX-License-Identifier: AGPL-3.0-or-later
#
# Completions for superpowers.
#
# One command (on or off); -g may come before or after it.

set -l subcmds on off help

complete -c superpowers -f
complete -c superpowers -s h -l help -d 'Show help'
complete -c superpowers -n 'not __fish_seen_argument -s g -l global' \
    -s g -l global -d 'Apply at the user (global) scope'

complete -c superpowers -n "not __fish_seen_subcommand_from $subcmds" \
    -a on -d 'Enable superpowers for antigravity-cli and Claude'
complete -c superpowers -n "not __fish_seen_subcommand_from $subcmds" \
    -a off -d 'Disable superpowers for antigravity-cli and Claude'
complete -c superpowers -n "not __fish_seen_subcommand_from $subcmds" \
    -a help -d 'Show help'
