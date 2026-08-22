# Copyright (C) 2026 Rootiest
# SPDX-License-Identifier: AGPL-3.0-or-later

# CATEGORY
#   08-terminal-management
#
# SYNOPSIS
#   bkg <command> [args...]
#
# DESCRIPTION
#   Launches a command in the background, fully detached from the terminal
#   using nohup. All stdout and stderr output is discarded. Simpler than
#   detach; no --version flag.
#
# ARGUMENTS
#   command  The command to run detached
#   args...  Additional arguments for the command
#
# EXIT STATUS
#   0  Command launched successfully
#   1  No command provided
#
# EXAMPLE
#   bkg firefox
function bkg --description 'Execute bkg'
    # Check if a command was provided as an argument.
    if test -z "$argv[1]"
        set -l c_head (set_color --bold cyan)
        set -l c_cmd (set_color --bold)
        set -l c_arg (set_color cyan)
        set -l c_reset (set_color normal)
        echo "$c_head""Usage:$c_reset $c_cmd""bkg$c_reset $c_arg""<command> [arguments...]$c_reset"
        return 1
    end

    # Run the command using nohup to make it immune to hangups (like closing the terminal).
    # Redirect both stdout and stderr to /dev/null to discard all output.
    # The final ampersand (&) sends the entire process to the background.
    nohup $argv &>/dev/null &
end
