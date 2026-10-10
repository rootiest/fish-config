# Copyright (C) 2026 Rootiest
# SPDX-License-Identifier: AGPL-3.0-or-later

# SYNOPSIS
#   _fish_deps_detect_pm
#
# DESCRIPTION
#   Detects and prints the name of the first available system package manager
#   from the priority list: paru, yay, pacman, apt, brew, pkg, dnf, zypper, yum.
#   Prints an empty string if none are found.
#
#   Only an executable on PATH counts. A function of the same name does not:
#   this config ships a pkg function, and matching it would make every
#   machine without paru, yay, pacman, apt or brew (Fedora, openSUSE, RHEL)
#   look like it has FreeBSD's pkg, and run `sudo pkg install` there.
#
# EXAMPLE
#   set pm (_fish_deps_detect_pm)
function _fish_deps_detect_pm
    for pm in paru yay pacman apt brew pkg dnf zypper yum
        # command -q, not type -q: a wrapper function must not pass for the
        # package manager (see the pkg function in this config).
        if command -q $pm
            echo $pm
            return
        end
    end
    echo ""
end
