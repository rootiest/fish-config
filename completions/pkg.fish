# Copyright (C) 2026 Rootiest
# SPDX-License-Identifier: AGPL-3.0-or-later
#
# Completions for pkg.
#
# Positionals are package names. With -u only installed packages make sense;
# otherwise (install, or auto mode, which toggles each package) every
# available one does.

complete -c pkg -f
complete -c pkg -s h -l help -d 'Show help'
complete -c pkg -n 'not __fish_seen_argument -s i -l install -s u -l uninstall' \
    -s i -l install -d 'Force install'
complete -c pkg -n 'not __fish_seen_argument -s i -l install -s u -l uninstall' \
    -s u -l uninstall -d 'Force uninstall'

complete -c pkg -n '__fish_seen_argument -s u -l uninstall' \
    -a '(__fish_print_packages --installed)'
complete -c pkg -n 'not __fish_seen_argument -s u -l uninstall' \
    -a '(__fish_print_packages)'
