# Copyright (C) 2026 Rootiest
# SPDX-License-Identifier: AGPL-3.0-or-later
#
# Completions for fish-deps.
#
# The first argument is a subcommand. install, update and sync then take
# catalog tool names; install and sync also take the tier flags.

function __fish_deps_complete_tools
    _fish_deps_catalog 2>/dev/null; or return
    for i in (seq (count $_fdc_bins))
        set -l tier
        switch $_fdc_tiers[$i]
            case req
                set tier Required
            case rec
                set tier Recommended
            case opt
                set tier Optional
            case term
                set tier 'Terminal emulator'
            case int
                set tier Integration
        end
        printf '%s\t%s\n' $_fdc_bins[$i] $tier
    end
end

set -l subcmds status install update sync help

complete -c fish-deps -f
complete -c fish-deps -s h -l help -d 'Show help'

complete -c fish-deps -n "not __fish_seen_subcommand_from $subcmds" \
    -a status -d 'Check installed and missing deps (default)'
complete -c fish-deps -n "not __fish_seen_subcommand_from $subcmds" \
    -a install -d 'Install missing deps interactively'
complete -c fish-deps -n "not __fish_seen_subcommand_from $subcmds" \
    -a update -d 'Update installed deps'
complete -c fish-deps -n "not __fish_seen_subcommand_from $subcmds" \
    -a sync -d 'Install missing deps, then update'
complete -c fish-deps -n "not __fish_seen_subcommand_from $subcmds" \
    -a help -d 'Show help'

# Tool names restrict install, update and sync to those catalog entries.
complete -c fish-deps -n "__fish_seen_subcommand_from install update sync" \
    -a '(__fish_deps_complete_tools)'
complete -c fish-deps -n "__fish_seen_subcommand_from install sync" \
    -a starship-config -d 'Replace the Starship config (keeps a backup)'

complete -c fish-deps -n "__fish_seen_subcommand_from install update sync" \
    -s y -l yes -d 'Take every default without asking'
complete -c fish-deps -n "__fish_seen_subcommand_from install sync" \
    -l optional -d 'Also offer Optional-tier deps'
complete -c fish-deps -n "__fish_seen_subcommand_from install sync" \
    -l terminals -d 'Also offer Terminal-Emulator-tier deps'
complete -c fish-deps -n "__fish_seen_subcommand_from install sync" \
    -l all -d 'Shorthand for --optional --terminals'
