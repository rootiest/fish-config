# Copyright (C) 2026 Rootiest
# SPDX-License-Identifier: AGPL-3.0-or-later

# Detect the first available system package manager.
function _fish_deps_detect_pm
    for pm in paru yay pacman apt brew pkg dnf yum
        if type -q $pm
            echo $pm
            return
        end
    end
    echo ""
end
