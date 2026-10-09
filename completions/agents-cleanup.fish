# Copyright (C) 2026 Rootiest
# SPDX-License-Identifier: AGPL-3.0-or-later
#
# Completions for agents-cleanup.

complete -c agents-cleanup -f
complete -c agents-cleanup -s h -l help -d 'Show help message'
complete -c agents-cleanup -s n -l dry-run -d 'Print the plan and change nothing'
complete -c agents-cleanup -l drop-extras -d 'Discard unlinked files in AGENTS/ instead of refusing'
complete -c agents-cleanup -l marker-file -d 'Also write .agents-disabled (required outside git)'
complete -c agents-cleanup -s v -l verbose -d 'Print all per-step output (default)'
complete -c agents-cleanup -s q -l quiet -d 'Print one summary line only if changes were made'
complete -c agents-cleanup -s s -l silent -d 'Suppress all output; errors only'
