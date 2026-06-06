# Copyright (C) 2026 Rootiest
# SPDX-License-Identifier: AGPL-3.0-or-later

# SYNOPSIS
#   fzf_configure_bindings [--directory=<key>] [--git_log=<key>] [--git_status=<key>]
#                          [--history=<key>] [--processes=<key>] [--variables=<key>] [-h]
#
# DESCRIPTION
#   Installs key bindings for fzf.fish in both insert and default vi modes.
#   Each binding can be overridden with a custom key or disabled by passing an
#   empty string. Only runs in interactive mode.
#
# ARGUMENTS
#   --directory=key   Override the directory search binding (default: Ctrl-Alt-F)
#   --git_log=key     Override the git log search binding (default: Ctrl-Alt-L)
#   --git_status=key  Override the git status binding (default: Ctrl-Alt-S)
#   --history=key     Override the history search binding (default: Ctrl-R)
#   --processes=key   Override the processes search binding (default: Ctrl-Alt-P)
#   --variables=key   Override the variables search binding (default: Ctrl-V)
#   -h, --help        Show help message
#
# RETURNS
#   0  Bindings installed or help shown
#   22 Invalid option or positional argument provided
#
# EXAMPLE
#   fzf_configure_bindings --history=ctrl-h
function fzf_configure_bindings --description "Installs the default key bindings for fzf.fish with user overrides passed as options."
    # no need to install bindings if not in interactive mode or running tests
    status is-interactive || test "$CI" = true; or return

    set -f options_spec h/help 'directory=?' 'git_log=?' 'git_status=?' 'history=?' 'processes=?' 'variables=?'
    argparse --max-args=0 --ignore-unknown $options_spec -- $argv 2>/dev/null
    if test $status -ne 0
        echo "Invalid option or a positional argument was provided." >&2
        _fzf_configure_bindings_help
        return 22
    else if set --query _flag_help
        _fzf_configure_bindings_help
        return
    else
        # Initialize with default key sequences and then override or disable them based on flags
        # index 1 = directory, 2 = git_log, 3 = git_status, 4 = history, 5 = processes, 6 = variables
        set -f key_sequences ctrl-alt-f ctrl-alt-l ctrl-alt-s ctrl-r ctrl-alt-p ctrl-v
        set --query _flag_directory && set key_sequences[1] "$_flag_directory"
        set --query _flag_git_log && set key_sequences[2] "$_flag_git_log"
        set --query _flag_git_status && set key_sequences[3] "$_flag_git_status"
        set --query _flag_history && set key_sequences[4] "$_flag_history"
        set --query _flag_processes && set key_sequences[5] "$_flag_processes"
        set --query _flag_variables && set key_sequences[6] "$_flag_variables"

        # If fzf bindings already exists, uninstall it first for a clean slate
        if functions --query _fzf_uninstall_bindings
            _fzf_uninstall_bindings
        end

        for mode in default insert
            test -n $key_sequences[1] && bind --mode $mode $key_sequences[1] _fzf_search_directory
            test -n $key_sequences[2] && bind --mode $mode $key_sequences[2] _fzf_search_git_log
            test -n $key_sequences[3] && bind --mode $mode $key_sequences[3] _fzf_search_git_status
            test -n $key_sequences[4] && bind --mode $mode $key_sequences[4] _fzf_search_history
            test -n $key_sequences[5] && bind --mode $mode $key_sequences[5] _fzf_search_processes
            test -n $key_sequences[6] && bind --mode $mode $key_sequences[6] "$_fzf_search_vars_command"
        end

        function _fzf_uninstall_bindings --inherit-variable key_sequences
            bind --erase -- $key_sequences
            bind --erase --mode insert -- $key_sequences
        end
    end
end
