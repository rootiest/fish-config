# Copyright (C) 2026 Rootiest
# SPDX-License-Identifier: AGPL-3.0-or-later

# SYNOPSIS
#   _fish_deps_pm_upgrade <pkg>
#
# DESCRIPTION
#   Upgrades an installed package via the detected system package manager,
#   running with sudo where required. Supports paru, yay, pacman, apt, brew,
#   pkg, dnf, zypper, and yum.
#
# ARGUMENTS
#   pkg  The package name to upgrade
#
# EXIT STATUS
#   0  Package upgraded successfully
#   1  No supported package manager found, or the upgrade failed
#
# EXAMPLE
#   _fish_deps_pm_upgrade ripgrep
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
        case zypper
            sudo zypper --non-interactive update $pkg
        case yum
            sudo yum update -y $pkg
        case '*'
            # detect_pm only prints names handled above, but a silent
            # no-op must never read as a successful upgrade.
            echo "_fish_deps_pm_upgrade: unsupported package manager '$pm'" >&2
            return 1
    end
end
