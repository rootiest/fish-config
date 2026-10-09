# Copyright (C) 2026 Rootiest
# SPDX-License-Identifier: AGPL-3.0-or-later
#
# Completions for edit.
#
# Positionals are the files to open, so file completion stays on. -V/-t and
# -v/-s are mutually exclusive (edit exits 2 on a conflict), so each pair stops
# being offered once one half is on the line.

complete -c edit -s h -l help -d 'Show help message'
complete -c edit -n 'not __fish_seen_argument -s V -l visual -s t -l terminal' -s V -l visual -d 'Force the GUI editor ($VISUAL or fallbacks)'
complete -c edit -n 'not __fish_seen_argument -s V -l visual -s t -l terminal' -s t -l terminal -d 'Force the terminal editor ($EDITOR or fallbacks)'
complete -c edit -s e -l editor -x -a '(__fish_complete_command)' -d 'Use a specific editor binary'
complete -c edit -s c -l clipboard -d 'Open the clipboard contents as a temp file'
complete -c edit -s x -l text -x -d 'Open the given string as a new temp file'
complete -c edit -s n -l new -d 'Force a new window or instance (best-effort)'
complete -c edit -n 'not __fish_seen_argument -s v -l verbose -s s -l silent' -s v -l verbose -d 'Print the launch command and editor output'
complete -c edit -n 'not __fish_seen_argument -s v -l verbose -s s -l silent' -s s -l silent -d 'Suppress all output, including the editor'
