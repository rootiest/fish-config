# Copyright (C) 2026 Rootiest
# SPDX-License-Identifier: AGPL-3.0-or-later

# Completions for the `jobrunner` background job manager.
# `jr` inherits these via `function jr --wraps jobrunner`.

# Offer running jobs as name<TAB>description pairs.
function __jobrunner_complete_jobs
    set -l tool ""
    set -l tokens (commandline -opc)
    set -l idx 1
    while test $idx -le (count $tokens)
        switch $tokens[$idx]
            case -t --tool
                set idx (math $idx + 1)
                if test $idx -le (count $tokens)
                    set tool $tokens[$idx]
                end
            case '--tool=*'
                set tool (string replace -- "--tool=" "" $tokens[$idx])
            case '-t*'
                set tool (string replace -r "^-t" "" $tokens[$idx])
        end
        set idx (math $idx + 1)
    end

    for row in (__jobrunner_sessions $tool)
        set -l f (string split \t -- $row)
        printf '%s\t%s job (PID %s)\n' $f[1] $f[3] $f[2]
    end
end

set -l subcmds run list attach kill logs help
set -l needs_job "__fish_seen_subcommand_from attach kill logs -a --attach -k --kill -o --output"

# No file completions; jobs are named, not paths.
complete -c jobrunner -f

# Backend tool selection flag.
complete -c jobrunner -n "not __fish_seen_subcommand_from $subcmds" \
    -s t -l tool -x -a "tmux screen" -d 'Force specific backend'

# Subcommands (only as the first argument).
complete -c jobrunner -n "not __fish_seen_subcommand_from $subcmds" \
    -a run -d 'Start a named job in the background'
complete -c jobrunner -n "not __fish_seen_subcommand_from $subcmds" \
    -a list -d 'List all managed background jobs'
complete -c jobrunner -n "not __fish_seen_subcommand_from $subcmds" \
    -a attach -d 'Re-attach interactively to a job'
complete -c jobrunner -n "not __fish_seen_subcommand_from $subcmds" \
    -a kill -d 'Terminate a running background job'
complete -c jobrunner -n "not __fish_seen_subcommand_from $subcmds" \
    -a logs -d "Print a job's output without attaching"
complete -c jobrunner -n "not __fish_seen_subcommand_from $subcmds" \
    -a help -d 'Show usage help'

# Flag forms.
complete -c jobrunner -n "not __fish_seen_subcommand_from $subcmds" \
    -s r -l run -d 'Start a named job in the background'
complete -c jobrunner -n "not __fish_seen_subcommand_from $subcmds" \
    -s l -l list -d 'List all managed background jobs'
complete -c jobrunner -n "not __fish_seen_subcommand_from $subcmds" \
    -s a -l attach -d 'Re-attach interactively to a job'
complete -c jobrunner -n "not __fish_seen_subcommand_from $subcmds" \
    -s k -l kill -d 'Terminate a running background job'
complete -c jobrunner -n "not __fish_seen_subcommand_from $subcmds" \
    -s o -l output -d "Print a job's output without attaching"
complete -c jobrunner -s h -l help -d 'Show usage help'

# Running jobs, for the subcommands that take one.
complete -c jobrunner -n "$needs_job" -a '(__jobrunner_complete_jobs)'

# A bare job name attaches to it, so offer jobs in first position too.
complete -c jobrunner -n "not __fish_seen_subcommand_from $subcmds" \
    -a '(__jobrunner_complete_jobs)'

# After `run <name>`, complete the command to execute.
complete -c jobrunner -n "__fish_seen_subcommand_from run -r --run; and test (count (commandline -opc)) -ge 3" \
    -a '(__fish_complete_subcommand)'
