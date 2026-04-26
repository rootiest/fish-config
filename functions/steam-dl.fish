# Copyright (C) 2026 Rootiest
# SPDX-License-Identifier: AGPL-3.0-or-later

function steam-dl --description 'Run Steam while inhibiting system sleep'
    echo "Inhibiting sleep while Steam downloads..."
    systemd-inhibit --why="Active Download" --who="User" --what=idle:sleep steam
end
