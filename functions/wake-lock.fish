# Copyright (C) 2026 Rootiest
# SPDX-License-Identifier: AGPL-3.0-or-later

# SYNOPSIS
#   wake-lock <command> [args...]
#
# DESCRIPTION
#   Runs a command under systemd-inhibit to prevent the system from idling
#   or sleeping for the duration of the command.
#
# ARGUMENTS
#   command  Command to run with sleep inhibition active
#   args...  Arguments forwarded to the command
#
# RETURNS
#   0  Command ran and completed
#   1  No command provided
#
# EXAMPLE
#   wake-lock rsync -avz src/ dest/
function wake-lock --description 'Run a command while inhibiting system sleep'
    if test (count $argv) -eq 0
        echo "Usage: wake-lock [command] [args...]"
        return 1
    end

    echo "Running '$argv' with sleep inhibition active..."

    # --what=idle:sleep prevents the system from auto-sleeping or being suspended
    # --who identifies your function in 'systemd-inhibit --list'
    systemd-inhibit --why="Manual task inhibition" --who="wake-lock" --what=idle:sleep $argv
end
