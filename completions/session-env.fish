# Copyright (C) 2026 Rootiest
# SPDX-License-Identifier: AGPL-3.0-or-later

# Completions for `session-env`. Groups and variables come from the catalog,
# data/session-env.tsv, so a new entry completes with no change here.

function __session_env_catalog_column --argument-names col
    set -l catalog $__fish_config_dir/data/session-env.tsv
    test -r $catalog; or return
    string match -rv '^\s*(#|$)' <$catalog | string split -f $col \t | sort -u
end

# Group names.
function __session_env_groups
    __session_env_catalog_column 1
end

function __session_env_vars
    set -l catalog $__fish_config_dir/data/session-env.tsv
    test -r $catalog; or return
    for line in (string match -rv '^\s*(#|$)' <$catalog)
        set -l f (string split \t -- $line)
        printf '%s\t%s\n' $f[3] $f[5]
    end
end

set -l subcmds install preview add remove sync apply select uninstall status list setup dismiss desktop help
set -l desktop_subcmds install uninstall preview status

complete -c session-env -f
complete -c session-env -s h -l help -d 'Show help'

# Subcommands, only in the first position.
complete -c session-env -f -n "not __fish_seen_subcommand_from $subcmds" -a install -d 'Write groups and variables'
complete -c session-env -f -n "not __fish_seen_subcommand_from $subcmds" -a preview -d 'Print what install would write'
complete -c session-env -f -n "not __fish_seen_subcommand_from $subcmds" -a add -d 'Add variables or groups'
complete -c session-env -f -n "not __fish_seen_subcommand_from $subcmds" -a remove -d 'Remove variables or groups'
complete -c session-env -f -n "not __fish_seen_subcommand_from $subcmds" -a sync -d 'Rewrite the file from its selection'
complete -c session-env -f -n "not __fish_seen_subcommand_from $subcmds" -a apply -d 'Push the selection into the running session'
complete -c session-env -f -n "not __fish_seen_subcommand_from $subcmds" -a select -d 'Pick variables in a checkbox list'
complete -c session-env -f -n "not __fish_seen_subcommand_from $subcmds" -a uninstall -d 'Remove the managed file'
complete -c session-env -f -n "not __fish_seen_subcommand_from $subcmds" -a status -d 'Show the file and whether it is stale'
complete -c session-env -f -n "not __fish_seen_subcommand_from $subcmds" -a list -d 'Show groups and variables'
complete -c session-env -f -n "not __fish_seen_subcommand_from $subcmds" -a setup -d 'Ask whether to install the default group'
complete -c session-env -f -n "not __fish_seen_subcommand_from $subcmds" -a dismiss -d 'Stop offering setup'
complete -c session-env -f -n "not __fish_seen_subcommand_from $subcmds" -a desktop -d 'User-level .desktop overrides'

# install / preview take groups; add / remove take groups or variables.
complete -c session-env -f -n "__fish_seen_subcommand_from install preview" -a '(__session_env_groups)'
complete -c session-env -f -n "__fish_seen_subcommand_from add remove" -a '(__session_env_groups)'
complete -c session-env -f -n "__fish_seen_subcommand_from add remove" -a '(__session_env_vars)'

# Selection flags.
complete -c session-env -f -n "__fish_seen_subcommand_from install preview" -l var -s v -x -a '(__session_env_vars)' -d 'Include one more variable'
complete -c session-env -f -n "__fish_seen_subcommand_from install preview" -l except -s x -x -a '(__session_env_vars)' -d 'Leave a variable out'
complete -c session-env -f -n "__fish_seen_subcommand_from install sync add remove select" -l now -s n -d 'Also apply to the running session'

# desktop COMMAND NAME [--var VAR] [--group GROUP]
complete -c session-env -f -n "__fish_seen_subcommand_from desktop; and not __fish_seen_subcommand_from $desktop_subcmds" -a "$desktop_subcmds"
complete -c session-env -f -n "__fish_seen_subcommand_from desktop; and __fish_seen_subcommand_from install" -l var -s v -x -a '(__session_env_vars)' -d 'Variable to unset'
complete -c session-env -f -n "__fish_seen_subcommand_from desktop; and __fish_seen_subcommand_from install" -l group -s g -x -a '(__session_env_groups)' -d 'Unset every variable of a group'
