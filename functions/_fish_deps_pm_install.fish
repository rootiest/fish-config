# Copyright (C) 2026 Rootiest
# SPDX-License-Identifier: AGPL-3.0-or-later

# Install a package via the system PM.
# Usage: _fish_deps_pm_install <pkg>
function _fish_deps_pm_install --argument-names pkg
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
            sudo apt install -y $pkg
        case brew
            brew install $pkg
        case pkg
            sudo pkg install -y $pkg
        case dnf
            sudo dnf install -y $pkg
        case yum
            sudo yum install -y $pkg
    end
end
