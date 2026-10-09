# Copyright (C) 2026 Rootiest
# SPDX-License-Identifier: AGPL-3.0-or-later

# SYNOPSIS
#   _fish_deps_pm_has_pkg PM PKG
#
# DESCRIPTION
#   Asks a package manager whether its index knows a package, so the
#   installer can leave out a method that is certain to fail ("E: Unable to
#   locate package ov" under apt, where ov is not packaged).
#
#   Only apt and pacman can answer cheaply and offline. Every other manager,
#   and the AUR helpers (whose lookups hit the network), are assumed to have
#   the package, which keeps their behavior exactly as it was.
#
# ARGUMENTS
#   PM   Package manager, as printed by _fish_deps_detect_pm
#   PKG  Package name as that manager spells it
#
# EXIT STATUS
#   0  The package is known, or the manager cannot be queried cheaply
#   1  The manager's index has no such package
#
# EXAMPLE
#   _fish_deps_pm_has_pkg apt ov; or echo "ov is not packaged for apt"
function _fish_deps_pm_has_pkg --argument-names pm pkg
    switch "$pm"
        case apt
            command apt-cache show $pkg >/dev/null 2>&1
        case pacman
            command pacman -Si $pkg >/dev/null 2>&1
        case '*'
            return 0
    end
end
