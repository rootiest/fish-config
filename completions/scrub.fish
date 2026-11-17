# Copyright (C) 2026 Rootiest
# SPDX-License-Identifier: AGPL-3.0-or-later
#
# Completions for scrub.
#
# Flags only; scrub always works on the current directory.

complete -c scrub -f
complete -c scrub -s h -l help -d 'Show help'
complete -c scrub -s a -l aggressive -d 'Also purge node_modules, logs, IDE and AI artifacts'
complete -c scrub -s d -l dry-run -d 'Show targets without deleting'
