# Copyright (C) 2026 Rootiest
# SPDX-License-Identifier: AGPL-3.0-or-later

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
