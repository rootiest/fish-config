# Copyright (C) 2026 Rootiest
# SPDX-License-Identifier: AGPL-3.0-or-later

# TEMPLATE  dispatcher
# KIND      target
# SUMMARY   One command with subcommands, each running its own command line
# PHRASE    Runs one of these subcommands: {keys:dispatcher_subcommands}
# SYNOPSIS  {name} SUBCOMMAND [ARGS...]
# STATUS    Exit status of the subcommand; 2 for an unknown subcommand
# EXAMPLE   {name} help

#   ─────────────────────────────── Settings ───────────────────────────────

# Subcommands, one per line, as name=command line; your extra arguments are added to the end. (lines, required)
set -l dispatcher_subcommands

# Subcommand to run when none is given; empty shows the help.
set -l dispatcher_default

#   ──────────────────────────── Fragment: run ─────────────────────────────

set -l __ft_sub $argv[1]
set -l __ft_rest $argv[2..]
set -q argv[1]; or set __ft_sub $dispatcher_default
if test -z "$__ft_sub"; or test "$__ft_sub" = help
    if functions -q __fish_help_header
        __fish_help_header (status current-function) --help
    else
        string replace -r -- '=.*' '' $dispatcher_subcommands
    end
    set __ft_status 0
else
    set -l __ft_line
    for __ft_pair in $dispatcher_subcommands
        set -l __ft_kv (string split -m1 = -- $__ft_pair)
        if test "$__ft_kv[1]" = "$__ft_sub"
            set __ft_line $__ft_kv[2]
            break
        end
    end
    if test -z "$__ft_line"
        echo (status current-function)": unknown subcommand '$__ft_sub'" >&2
        echo "Run "(status current-function)" help for usage." >&2
        set __ft_status 2
    else
        eval $__ft_line (string escape -- $__ft_rest)
        set __ft_status $status
    end
end
