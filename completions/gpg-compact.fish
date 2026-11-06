# Copyright (C) 2026 Rootiest
# SPDX-License-Identifier: AGPL-3.0-or-later
#
# Completions for gpg-compact.
#
# Positionals are gpg key specifiers, never files.

complete -c gpg-compact -f
complete -c gpg-compact -s h -l help -d 'Show help message'
complete -c gpg-compact -s K -l secret -d 'List secret keys (default)'
complete -c gpg-compact -s k -l public -d 'List public keys'
