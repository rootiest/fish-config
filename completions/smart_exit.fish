# Copyright (C) 2026 Rootiest
# SPDX-License-Identifier: AGPL-3.0-or-later
#
# Completions for smart_exit.
#
# `exit` is rewired to smart_exit only when the C3 overrides are enabled, so
# this covers the function by its own name and does not claim `exit`.

complete -c smart_exit -f
complete -c smart_exit -s h -l help -d 'Show help message'
complete -c smart_exit -s n -l no-log -d 'Exit without saving a scrollback log'
