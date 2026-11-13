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
#   The two Integrations clients are spelled differently almost everywhere:
#
#     github-cli  is gh outside the Arch family (apt, dnf, yum, zypper,
#                 brew, pkg).
#     gitea-cli   (gt, the official Gitea CLI) keeps its name where it is
#                 packaged (Arch, Homebrew; apt only if its index has it).
#                 dnf, yum, zypper and pkg carry no package, so they have
#                 none and the release download is used.
#
#   A NAME with no special mapping is printed unchanged.
#
# ARGUMENTS
#   PM    Package manager, as printed by _fish_deps_detect_pm
#   NAME  Catalog package name, or one of the generic requirements: cc, go
#
# EXIT STATUS
#   0  A package name was printed
#   1  PM has no package for that requirement or tool (nothing is printed)
#
# RETURNS
#   The package name on stdout
#
# EXAMPLE
#   _fish_deps_pm_pkg apt go     # golang-go
#   _fish_deps_pm_pkg apt github-cli     # gh
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
        case github-cli
            switch "$pm"
                case pacman paru yay
                    echo github-cli
                case '*'
                    echo gh
            end
        case gitea-cli
            switch "$pm"
                case dnf yum zypper pkg
                    return 1
                case '*'
                    echo gitea-cli
            end
        case '*'
            echo $name
    end
    return 0
end
