# Copyright (C) 2026 Rootiest
# SPDX-License-Identifier: AGPL-3.0-or-later
#
# Completions for md.
#
# md wraps marktext, which supplies the rest; these are the two options md
# consumes itself.

complete -c md -s r -l read-only -d 'Open read-only, sandboxed with firejail'
complete -c md -l foreground -d 'Stay attached to the terminal'
