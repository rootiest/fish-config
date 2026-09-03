# Copyright (C) 2026 Rootiest
# SPDX-License-Identifier: AGPL-3.0-or-later
#
# Completions for agents-vault.

complete -c agents-vault -f
complete -c agents-vault -s h -l help -d 'Show help message'
complete -c agents-vault -l link -d "Ensure this project's memory link only"
complete -c agents-vault -l push -d 'Commit and push to the vault remote'
complete -c agents-vault -l restore -d 'Relink everything possible, report the rest'
complete -c agents-vault -l status -d 'Show entries, link health, remote, orphans'
# --adopt takes an existing vault slug, so offer the entries that are
# actually there; the vault may not exist yet, in which case this is empty.
complete -c agents-vault -l adopt -r -a '(command ls -1 (_agents_vault_dir)/projects 2>/dev/null)' -d 'Bind this project to an existing vault entry'
complete -c agents-vault -l remote -r -d 'Set the vault remote URL'
complete -c agents-vault -s v -l verbose -d 'Print all per-step output (default)'
complete -c agents-vault -s q -l quiet -d 'Print one summary line only if changed'
complete -c agents-vault -s s -l silent -d 'Suppress all output; errors only'
