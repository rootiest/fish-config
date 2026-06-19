# Copyright (C) 2026 Rootiest
# SPDX-License-Identifier: AGPL-3.0-or-later

# Completions for the `auto-pull` registry command.

function __auto_pull_registered
    set -l list "$XDG_CONFIG_HOME/.user-dots/fish/auto-pull.list"
    test -r "$list"; or return
    for l in (command cat "$list" 2>/dev/null)
        test -n "$l"; or continue
        printf '%s\t%s\n' (path basename "$l") "$l"
    end
end

set -l subcmds list add remove status

# Subcommands (only as the first argument).
complete -c auto-pull -f -n "not __fish_seen_subcommand_from $subcmds" \
    -a list -d 'Show registered repos'
complete -c auto-pull -f -n "not __fish_seen_subcommand_from $subcmds" \
    -a add -d "Register a repo (default: current)"
complete -c auto-pull -f -n "not __fish_seen_subcommand_from $subcmds" \
    -a remove -d 'Unregister a repo'
complete -c auto-pull -f -n "not __fish_seen_subcommand_from $subcmds" \
    -a status -d 'Show enabled state and registry path'
complete -c auto-pull -f -n "not __fish_seen_subcommand_from $subcmds" \
    -s h -l help -d 'Show help'

# `add` takes a directory path.
complete -c auto-pull -n "__fish_seen_subcommand_from add" -a '(__fish_complete_directories)'

# `remove` completes registered repo basenames.
complete -c auto-pull -f -n "__fish_seen_subcommand_from remove" -a '(__auto_pull_registered)'
