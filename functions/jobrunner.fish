# Copyright (C) 2026 Rootiest
# SPDX-License-Identifier: AGPL-3.0-or-later

# CATEGORY
#   08-terminal-management
#
# DEPENDENCIES
#   tmux, screen, __jobrunner_sessions
#
# SYNOPSIS
#   jobrunner [-t <tool>] [<subcommand>] [<name>] [<command>...]
#   jr [-t <tool>] [<subcommand>] [<name>] [<command>...]
#
# DESCRIPTION
#   Runs, lists, inspects, re-attaches to, and terminates named background
#   jobs using tmux or GNU screen as the process engine. Unlike bkg and
#   detach, which discard output, a jobrunner job keeps a live terminal you
#   can return to later — it survives closing the shell, and `attach`
#   restores it in any subsequent session.
#
#   Every subcommand has a matching flag form, and the common cases are
#   inferred: no arguments lists jobs, a lone name attaches to it, and a
#   name followed by a command runs it.
#
# ARGUMENTS
#   -t, --tool <name>                Force specific backend (tmux or screen)
#   run, -r, --run <name> <cmd>...   Start a named job in the background
#   list, -l, --list                 List all managed background jobs
#   attach, -a, --attach <name>      Re-attach interactively to a job
#   kill, -k, --kill <name>          Terminate a running background job
#   logs, -o, --output <name>        Print a job's current output, no attach
#   help, -h, --help                 Show usage help
#
# EXIT STATUS
#   0    Command succeeded, or no jobs are running
#   1    Invalid arguments, or the named job does not exist
#   127  neither tmux nor screen is installed
#
# EXAMPLE
#   jobrunner run build make -j8
#   jobrunner -t screen run backup rsync -a ./data remote:/backup/
#   jobrunner list
#   jobrunner logs build
#   jobrunner build
#   jobrunner kill build
#
# NOTES
#   Detach from an attached job with Ctrl-A then D; the job keeps running.
#   Commands are executed directly rather than through a shell, so pipes and
#   redirections must be wrapped explicitly, e.g.
#   `jobrunner run sync fish -c 'a | b'`.
function jobrunner --description 'Manage detached background jobs with tmux or GNU screen'
    set -l c_head (set_color --bold cyan)
    set -l c_cmd (set_color --bold white)
    set -l c_arg (set_color cyan)
    set -l c_flag (set_color yellow)
    set -l c_ok (set_color green)
    set -l c_err (set_color red)
    set -l c_dim (set_color brblack)
    set -l c_rst (set_color normal)

    set -l subcmds run list attach kill logs help \
        -r --run -l --list -a --attach -k --kill -o --output -h --help

    # ╭──────────────────────────────────────────────────────────╮
    # │ Tool Extraction                                          │
    # ╰──────────────────────────────────────────────────────────╯
    set -l tool ""
    while test (count $argv) -gt 0
        switch $argv[1]
            case -t
                set tool $argv[2]
                set -e argv[1..2]
            case --tool
                set tool $argv[2]
                set -e argv[1..2]
            case '--tool=*'
                set tool (string replace -- "--tool=" "" $argv[1])
                set -e argv[1]
            case '-t*'
                set tool (string replace -r "^-t" "" $argv[1])
                set -e argv[1]
            case '*'
                break
        end
    end

    # ╭──────────────────────────────────────────────────────────╮
    # │ Help                                                     │
    # ╰──────────────────────────────────────────────────────────╯
    # Answered before the dependency check so usage is readable anywhere.
    if set -q argv[1]; and contains -- $argv[1] help -h --help
        echo "$c_head""Usage:$c_rst $c_cmd""jobrunner$c_rst $c_arg""[<subcommand>] [<name>] [<command>...]$c_rst"
        echo
        echo "  Run and manage named background jobs backed by tmux or GNU screen."
        echo
        echo "$c_head""Subcommands:$c_rst"
        echo "  $c_cmd""run$c_rst $c_arg""<name> <cmd>...$c_rst   Start a named job in the background"
        echo "  $c_cmd""list$c_rst                  List all managed background jobs"
        echo "  $c_cmd""attach$c_rst $c_arg""<name>$c_rst         Re-attach interactively to a job"
        echo "  $c_cmd""kill$c_rst $c_arg""<name>$c_rst           Terminate a running background job"
        echo "  $c_cmd""logs$c_rst $c_arg""<name>$c_rst           Print a job's output without attaching"
        echo
        echo "$c_head""Flags:$c_rst"
        echo "  $c_flag-t$c_rst, $c_flag--tool$c_rst $c_arg<name>$c_rst   Force specific backend (tmux or screen)"
        echo "  $c_flag-r$c_rst, $c_flag--run$c_rst      Same as $c_cmd""run$c_rst"
        echo "  $c_flag-l$c_rst, $c_flag--list$c_rst     Same as $c_cmd""list$c_rst"
        echo "  $c_flag-a$c_rst, $c_flag--attach$c_rst   Same as $c_cmd""attach$c_rst"
        echo "  $c_flag-k$c_rst, $c_flag--kill$c_rst     Same as $c_cmd""kill$c_rst"
        echo "  $c_flag-o$c_rst, $c_flag--output$c_rst   Same as $c_cmd""logs$c_rst"
        echo "  $c_flag-h$c_rst, $c_flag--help$c_rst     Show this help message"
        echo
        echo "$c_head""Shorthands:$c_rst"
        echo "  $c_cmd""jobrunner$c_rst                     $c_dim""list$c_rst"
        echo "  $c_cmd""jobrunner$c_rst $c_arg""<name>$c_rst              $c_dim""attach <name>$c_rst"
        echo "  $c_cmd""jobrunner$c_rst $c_arg""<name> <cmd>...$c_rst     $c_dim""run <name> <cmd>...$c_rst"
        echo
        echo "$c_head""Examples:$c_rst"
        echo "  $c_cmd""jobrunner$c_rst $c_arg""run build$c_rst""$c_dim"" make -j8$c_rst"
        echo "  $c_cmd""jobrunner$c_rst $c_arg""logs build$c_rst"
        echo "  $c_cmd""jobrunner$c_rst $c_arg""kill build$c_rst"
        echo
        echo "$c_dim""Detach from an attached job with Ctrl-A then D.$c_rst"
        return 0
    end

    # ╭──────────────────────────────────────────────────────────╮
    # │ Dependency check                                         │
    # ╰──────────────────────────────────────────────────────────╯
    if test -n "$tool"
        if not contains -- $tool tmux screen
            echo "$c_err""jobrunner:$c_rst invalid tool '$c_arg$tool$c_rst', must be 'tmux' or 'screen'." >&2
            return 1
        end
        if not command -q $tool
            echo "$c_err""jobrunner:$c_rst '$tool' is required but was not found in PATH." >&2
            return 127
        end
    else
        if command -q tmux
            set tool tmux
        else if command -q screen
            set tool screen
        else
            echo "$c_err""jobrunner:$c_rst neither 'tmux' nor 'screen' was found in PATH." >&2
            return 127
        end
    end

    # ╭──────────────────────────────────────────────────────────╮
    # │ Argument pre-processing                                  │
    # ╰──────────────────────────────────────────────────────────╯
    set -q argv[1]; or set argv list
    set -l cmd $argv[1]

    if not contains -- $cmd $subcmds
        if test (count $argv) -eq 1
            # A lone name attaches, but only if that job actually exists.
            if contains -- $cmd (__jobrunner_sessions $tool | string replace -r '\t.*$' '')
                set argv attach $argv
                set cmd attach
            else
                echo "$c_err""jobrunner:$c_rst unknown subcommand or job '$c_arg$cmd$c_rst'." >&2
                echo "Run $c_cmd""jobrunner --help$c_rst for usage." >&2
                return 1
            end
        else
            # A name plus a command line is an implicit run.
            set argv run $argv
            set cmd run
        end
    end

    # ╭──────────────────────────────────────────────────────────╮
    # │ Dispatch                                                 │
    # ╰──────────────────────────────────────────────────────────╯
    switch $cmd
        case run -r --run
            if test (count $argv) -lt 3
                echo "$c_head""Usage:$c_rst $c_cmd""jobrunner run$c_rst $c_arg""<name> <command>...$c_rst" >&2
                return 1
            end
            set -l name $argv[2]
            set -l task $argv[3..-1]

            # screen stores each session as a socket file named after it.
            if string match -q '*/*' -- $name
                echo "$c_err""jobrunner:$c_rst job name may not contain '/'." >&2
                return 1
            end
            if contains -- $name (__jobrunner_sessions $tool | string replace -r '\t.*$' '')
                echo "$c_err""jobrunner:$c_rst job '$c_arg$name$c_rst' is already running." >&2
                return 1
            end

            if test "$tool" = tmux
                command tmux new-session -d -s $name $task
            else
                command screen -d -m -S $name $task
            end
            or begin
                echo "$c_err""jobrunner:$c_rst failed to start job '$c_arg$name$c_rst'." >&2
                return 1
            end

            set -l pid
            for row in (__jobrunner_sessions $tool)
                set -l f (string split \t -- $row)
                test "$f[1]" = "$name"; and set pid $f[2]; and break
            end

            if set -q pid[1]
                echo "$c_ok""✔$c_rst  Started job $c_arg$name$c_rst $c_dim(PID $pid)$c_rst"
            else
                # The job may have finished (or failed) before we looked.
                echo "$c_ok""✔$c_rst  Started job $c_arg$name$c_rst $c_dim(already exited)$c_rst"
            end

        case list -l --list
            set -l rows (__jobrunner_sessions $tool)
            if test (count $rows) -eq 0
                echo "No background jobs running."
                return 0
            end

            printf '%s%-20s  %-8s  %-10s  %s%s\n' "$c_head" JOB PID STATE STARTED "$c_rst"
            for row in $rows
                set -l f (string split \t -- $row)
                printf '%s%-20s%s  %-8s  %-10s  %s%s%s\n' \
                    "$c_arg" $f[1] "$c_rst" $f[2] $f[3] "$c_dim" $f[4] "$c_rst"
            end

        case attach -a --attach
            if test (count $argv) -ne 2
                echo "$c_head""Usage:$c_rst $c_cmd""jobrunner attach$c_rst $c_arg""<name>$c_rst" >&2
                return 1
            end
            set -l name $argv[2]
            if not contains -- $name (__jobrunner_sessions $tool | string replace -r '\t.*$' '')
                echo "$c_err""jobrunner:$c_rst no such job '$c_arg$name$c_rst'." >&2
                return 1
            end
            if test "$tool" = tmux
                command tmux attach-session -t $name
            else
                # -x attaches to an already-attached session instead of failing.
                command screen -x $name
            end

        case kill -k --kill
            if test (count $argv) -ne 2
                echo "$c_head""Usage:$c_rst $c_cmd""jobrunner kill$c_rst $c_arg""<name>$c_rst" >&2
                return 1
            end
            set -l name $argv[2]
            if not contains -- $name (__jobrunner_sessions $tool | string replace -r '\t.*$' '')
                echo "$c_err""jobrunner:$c_rst no such job '$c_arg$name$c_rst'." >&2
                return 1
            end
            if test "$tool" = tmux
                command tmux kill-session -t $name
            else
                command screen -X -S $name quit
            end
            or begin
                echo "$c_err""jobrunner:$c_rst failed to terminate job '$c_arg$name$c_rst'." >&2
                return 1
            end
            echo "$c_ok""✔$c_rst  Terminated job $c_arg$name$c_rst"

        case logs -o --output
            if test (count $argv) -ne 2
                echo "$c_head""Usage:$c_rst $c_cmd""jobrunner logs$c_rst $c_arg""<name>$c_rst" >&2
                return 1
            end
            set -l name $argv[2]
            if not contains -- $name (__jobrunner_sessions $tool | string replace -r '\t.*$' '')
                echo "$c_err""jobrunner:$c_rst no such job '$c_arg$name$c_rst'." >&2
                return 1
            end

            set -l out
            if test "$tool" = tmux
                # capture-pane -S - -p outputs the scrollback and current pane directly to stdout.
                set out (command tmux capture-pane -t $name -S - -p)
                or begin
                    echo "$c_err""jobrunner:$c_rst could not read output of '$c_arg$name$c_rst'." >&2
                    return 1
                end
            else
                # hardcopy -h dumps scrollback plus the visible screen to a file.
                # ponytail: snapshot only; add `screen -L` logging if full
                # since-start history is ever needed.
                set -l dump (command mktemp)
                command screen -X -S $name hardcopy -h $dump
                or begin
                    command rm -f $dump
                    echo "$c_err""jobrunner:$c_rst could not read output of '$c_arg$name$c_rst'." >&2
                    return 1
                end

                set out (command cat $dump)
                command rm -f $dump
            end

            # hardcopy (and sometimes tmux) pad the dump with empty lines.
            while set -q out[1]; and test -z "$out[-1]"
                set -e out[-1]
            end
            if set -q out[1]
                printf '%s\n' $out
            else
                echo "$c_dim(no output yet)$c_rst"
            end

        case '*'
            echo "$c_err""jobrunner:$c_rst invalid subcommand '$c_arg$cmd$c_rst'." >&2
            echo "Run $c_cmd""jobrunner --help$c_rst for usage." >&2
            return 1
    end
end
