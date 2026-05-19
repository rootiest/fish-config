# Copyright (C) 2026 Rootiest
# SPDX-License-Identifier: AGPL-3.0-or-later

# Upgrade an already-installed package via the system PM.
# Usage: _fish_deps_pm_upgrade <pkg>
function _fish_deps_pm_upgrade --argument-names pkg
    set -l pm (_fish_deps_detect_pm)
    if test -z "$pm"
        echo "No supported package manager found." >&2
        return 1
    end
    switch $pm
        case paru yay
            $pm -S --noconfirm $pkg
        case pacman
            sudo pacman -S --noconfirm $pkg
        case apt
            sudo apt install --only-upgrade -y $pkg
        case brew
            brew upgrade $pkg
        case pkg
            sudo pkg upgrade -y $pkg
        case dnf
            sudo dnf upgrade -y $pkg
        case yum
            sudo yum update -y $pkg
    end
end
