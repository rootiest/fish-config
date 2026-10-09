# Copyright (C) 2026 Rootiest
# SPDX-License-Identifier: AGPL-3.0-or-later

# SYNOPSIS
#   _fish_deps_pm_pkg PM NAME
#
# DESCRIPTION
#   Translates a generic requirement into the package name a given package
#   manager uses for it. The catalog records Arch-style names, which are not
#   what Debian or Fedora call things (go is golang-go under apt and
#   golang under dnf), and a few requirements are not single packages at
#   all (cc is build-essential under apt, base-devel under pacman).
#
#   A NAME with no special mapping is printed unchanged.
#
# ARGUMENTS
#   PM    Package manager, as printed by _fish_deps_detect_pm
#   NAME  Catalog package name, or one of the generic requirements: cc, go
#
# EXIT STATUS
#   0  A package name was printed
#   1  PM has no package for that requirement (nothing is printed)
#
# RETURNS
#   The package name on stdout
#
# EXAMPLE
#   _fish_deps_pm_pkg apt go     # golang-go
function _fish_deps_pm_pkg --argument-names pm name
    switch "$name"
        case cc
            switch "$pm"
                case apt
                    echo build-essential
                case pacman paru yay
                    echo base-devel
                case dnf yum zypper
                    echo gcc
                case '*'
                    return 1
            end
        case go
            switch "$pm"
                case apt
                    echo golang-go
                case dnf yum
                    echo golang
                case '*'
                    echo go
            end
        case '*'
            echo $name
    end
    return 0
end
