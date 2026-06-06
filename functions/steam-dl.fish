# Copyright (C) 2026 Rootiest
# SPDX-License-Identifier: AGPL-3.0-or-later

# SYNOPSIS
#   steam-dl
#
# DESCRIPTION
#   Launches Steam with systemd-inhibit to prevent the system from idling
#   or sleeping during active downloads.
#
# EXAMPLE
#   steam-dl
function steam-dl --description 'Run Steam while inhibiting system sleep'
    echo "Inhibiting sleep while Steam downloads..."
    systemd-inhibit --why="Active Download" --who="User" --what=idle:sleep steam
end
