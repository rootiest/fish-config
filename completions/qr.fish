# Copyright (C) 2026 Rootiest
# SPDX-License-Identifier: AGPL-3.0-or-later
#
# Completions for qr.
#
# The positional is free text to encode (or stdin), so file completion is off.

complete -c qr -f
complete -c qr -s h -l help -d 'Show help message'
complete -c qr -s o -l online -d 'Allow the qrenco.de fallback when qrencode is missing'
