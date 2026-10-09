# Copyright (C) 2026 Rootiest
# SPDX-License-Identifier: AGPL-3.0-or-later
#
# Completions for dng2avif.
#
# The positional (and --input) is a DNG file; --output is an AVIF path.

complete -c dng2avif -s h -l help -d 'Show help message'
complete -c dng2avif -s i -l input -r -F -d 'Input DNG file'
complete -c dng2avif -s o -l output -r -F -d 'Output AVIF file (defaults to input name)'
complete -c dng2avif -s q -l quality -x -a '70 80 85 92 100' -d 'Encoding quality 0-100 (default: 92)'
complete -c dng2avif -s s -l speed -x -a '0 1 2 3 4 5 6 7 8 9 10' -d 'Encoder speed 0-10 (default: 3, 0 = slowest)'
