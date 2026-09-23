# Copyright (C) 2026 Rootiest
# SPDX-License-Identifier: AGPL-3.0-or-later

# CATEGORY
#   13-media-and-utilities
#
# DEPENDENCIES
#   systemd-inhibit, steam
#
# SYNOPSIS
#   steam-dl
#
# DESCRIPTION
#   Launches Steam with systemd-inhibit to prevent the system from idling
#   or sleeping during active downloads.
#
# EXIT STATUS
#   1  systemd-inhibit or steam is not installed
#   *  Exit status of steam (via systemd-inhibit) otherwise
#
# EXAMPLE
#   steam-dl
function steam-dl --description 'Run Steam while inhibiting system sleep'
    __fish_help_header (status current-function) $argv; and return 0

    for cmd in systemd-inhibit steam
        if not type -q $cmd
            echo (set_color red)"Error: $cmd is not installed."(set_color normal) >&2
            return 1
        end
    end

    echo "Inhibiting sleep while Steam downloads..."
    systemd-inhibit --why="Active Download" --who="User" --what=idle:sleep steam
end
