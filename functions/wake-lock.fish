# Copyright (C) 2026 Rootiest
# SPDX-License-Identifier: AGPL-3.0-or-later

# CATEGORY
#   14-miscellaneous
#
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
# EXIT STATUS
#   0  Command ran and completed
#   1  No command provided
#
# EXAMPLE
#   wake-lock rsync -avz src/ dest/
function wake-lock --description 'Run a command while inhibiting system sleep'
    if test (count $argv) -eq 0
        set -l c_head (set_color --bold cyan)
        set -l c_cmd (set_color --bold)
        set -l c_arg (set_color cyan)
        set -l c_reset (set_color normal)
        echo "$c_head""Usage:$c_reset $c_cmd""wake-lock$c_reset $c_arg""[command] [args...]$c_reset"
        return 1
    end

    echo "Running '$argv' with sleep inhibition active..."

    # --what=idle:sleep prevents the system from auto-sleeping or being suspended
    # --who identifies your function in 'systemd-inhibit --list'
    systemd-inhibit --why="Manual task inhibition" --who="wake-lock" --what=idle:sleep $argv
end
