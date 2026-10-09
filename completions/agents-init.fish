# Copyright (C) 2026 Rootiest
# SPDX-License-Identifier: AGPL-3.0-or-later
#
# Completions for agents-init.

complete -c agents-init -f
complete -c agents-init -s h -l help -d 'Show help message'
complete -c agents-init -s a -l agents -d 'Set up AGENTS.md symlinks only'
complete -c agents-init -s p -l plugins -d 'Set up plans/specs/devlogs dirs and docs/ symlinks only'
complete -c agents-init -s e -l enable -d 'Re-enable a project agents-cleanup disabled'
complete -c agents-init -l public -d 'Public AGENTS.md (default); migrate a private project'
complete -c agents-init -l private -d 'Keep AGENTS.md private in AGENTS/ (new projects only)'
complete -c agents-init -s v -l verbose -d 'Print all per-step output (default)'
complete -c agents-init -s q -l quiet -d 'Print one summary line only if changes were made'
complete -c agents-init -s s -l silent -d 'Suppress all output; errors only'
