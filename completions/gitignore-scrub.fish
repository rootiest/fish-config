# Copyright (C) 2026 Rootiest
# SPDX-License-Identifier: AGPL-3.0-or-later
#
# Completions for gitignore-scrub.
#
# -w, -f and -i are mutually exclusive (argparse --exclusive), so once one of
# them is on the line the other two stop being offered. -r combines with any.

complete -c gitignore-scrub -f
complete -c gitignore-scrub -s h -l help -d 'Show help message'
complete -c gitignore-scrub -s r -l reset -d 'Clear the remembered skip list before checking'
complete -c gitignore-scrub -n 'not __fish_seen_argument -s w -l warn -s f -l force -s i -l individual' -s w -l warn -d 'Read-only: print warnings instead of prompting'
complete -c gitignore-scrub -n 'not __fish_seen_argument -s w -l warn -s f -l force -s i -l individual' -s f -l force -d 'Untrack every match immediately, no prompt'
complete -c gitignore-scrub -n 'not __fish_seen_argument -s w -l warn -s f -l force -s i -l individual' -s i -l individual -d 'Prompt once per file instead of once for the group'
