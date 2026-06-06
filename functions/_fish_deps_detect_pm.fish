# Copyright (C) 2026 Rootiest
# SPDX-License-Identifier: AGPL-3.0-or-later

# SYNOPSIS
#   _fish_deps_detect_pm
#
# DESCRIPTION
#   Detects and prints the name of the first available system package manager
#   from the priority list: paru, yay, pacman, apt, brew, pkg, dnf, yum.
#   Prints an empty string if none are found.
#
# EXAMPLE
#   set pm (_fish_deps_detect_pm)
function _fish_deps_detect_pm
    for pm in paru yay pacman apt brew pkg dnf yum
        if type -q $pm
            echo $pm
            return
        end
    end
    echo ""
end
