# Copyright (C) 2026 Rootiest
# SPDX-License-Identifier: AGPL-3.0-or-later

# Function to run a command in the background, detached from the terminal.
# This prevents the command from being terminated when the terminal is closed.
# All output (stdout and stderr) is discarded.
#
# Usage:
#   bkg <command> [arguments...]
#
# Example:
#   bkg firefox
#   bkg code .
#
function bkg
    # Check if a command was provided as an argument.
    if test -z "$argv[1]"
        echo "Usage: bkg <command> [arguments...]"
        return 1
    end

    # Run the command using nohup to make it immune to hangups (like closing the terminal).
    # Redirect both stdout and stderr to /dev/null to discard all output.
    # The final ampersand (&) sends the entire process to the background.
    nohup $argv &>/dev/null &
end
