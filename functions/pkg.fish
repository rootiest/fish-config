# Copyright (C) 2026 Rootiest
# SPDX-License-Identifier: AGPL-3.0-or-later

# CATEGORY
#   05-package-management
#
# SYNOPSIS
#   pkg [-h] [-i|-u] <package> [package...]
#
# DESCRIPTION
#   Installs or removes packages using the system's available package manager.
#   Supports paru, yay, pacman, apt, dnf, zypper, yum, brew, and pkg.
#   In auto mode (no flag), detects whether each package is installed and
#   toggles it — installing if absent, removing if present.
#
#   The package-installed check uses the correct query for each manager:
#
#     pacman/paru/yay  pacman -Qi
#     apt              dpkg -s
#     dnf/zypper/yum   rpm -q
#     brew             brew list
#     pkg              pkg info
#
# ARGUMENTS
#   -h, --help       Show help message
#   -i, --install    Force install mode
#   -u, --uninstall  Force uninstall mode
#   package          One or more package names to install or remove
#
# EXIT STATUS
#   0  Operation completed
#   1  No supported package manager found, unknown flag, or package operation failed
#
# EXAMPLE
#   pkg firefox
#   pkg -i ripgrep fd-find
#   pkg -u cowsay
function pkg --description 'Install or remove packages via the system package manager'
    # ── Package manager detection ────────────────────────────────
    set -l pm (_fish_deps_detect_pm)
    if test -z "$pm"
        set_color red
        echo "error: no supported package manager found" >&2
        set_color normal
        return 1
    end

    # ── Colour palette ───────────────────────────────────────────
    set -l c_head (set_color --bold cyan)
    set -l c_cmd (set_color --bold)
    set -l c_flag (set_color yellow)
    set -l c_ok (set_color green)
    set -l c_warn (set_color yellow)
    set -l c_err (set_color red)
    set -l c_dim (set_color brblack)
    set -l c_reset (set_color normal)

    # ── Installed-check helper ───────────────────────────────────
    # Uses only its own arguments — safe to define as an inner function.
    function __pkg_is_installed --argument-names _pm _pkg
        switch $_pm
            case paru yay pacman
                pacman -Qi $_pkg &>/dev/null
            case apt
                dpkg -s $_pkg &>/dev/null
            case dnf zypper yum
                rpm -q $_pkg &>/dev/null
            case brew
                brew list $_pkg &>/dev/null
            case pkg
                pkg info $_pkg &>/dev/null
        end
    end

    # ── Argument parsing ─────────────────────────────────────────
    set -l mode auto
    set -l packages

    for arg in $argv
        switch $arg
            case -h --help
                echo "$c_head""Usage:$c_reset $c_cmd""pkg$c_reset " \
                    "$c_flag""[-h] [-i] [-u]$c_reset $c_dim""<package>...$c_reset"
                echo
                echo "  Install or remove packages via $pm."
                echo
                echo "$c_head""Flags:$c_reset"
                echo "  $c_flag-h$c_reset, $c_flag--help$c_reset       " \
                    "Show this help message"
                echo "  $c_flag-i$c_reset, $c_flag--install$c_reset    " \
                    "Force install"
                echo "  $c_flag-u$c_reset, $c_flag--uninstall$c_reset  " \
                    "Force uninstall"
                echo
                echo "$c_head""Auto mode (no flag):$c_reset"
                echo "  Checks if each package is installed and installs" \
                    "or removes accordingly."
                functions -e __pkg_is_installed
                return 0
            case -i --install
                set mode install
            case -u --uninstall
                set mode uninstall
            case --
                # stop flag parsing
            case '-*'
                echo "$c_err""error:$c_reset unknown flag $c_flag$arg$c_reset" >&2
                functions -e __pkg_is_installed
                return 1
            case '*'
                set packages $packages $arg
        end
    end

    if test (count $packages) -eq 0
        echo "$c_head""Usage:$c_reset $c_cmd""pkg$c_reset " \
            "$c_flag""[-h] [-i] [-u]$c_reset $c_dim""<package>...$c_reset"
        echo
        echo "  Install or remove packages via $pm."
        echo
        echo "$c_head""Flags:$c_reset"
        echo "  $c_flag-h$c_reset, $c_flag--help$c_reset       " \
            "Show this help message"
        echo "  $c_flag-i$c_reset, $c_flag--install$c_reset    " \
            "Force install"
        echo "  $c_flag-u$c_reset, $c_flag--uninstall$c_reset  " \
            "Force uninstall"
        echo
        echo "$c_head""Auto mode (no flag):$c_reset"
        echo "  Checks if each package is installed and installs" \
            "or removes accordingly."
        functions -e __pkg_is_installed
        return 0
    end

    # ── Mode dispatch ────────────────────────────────────────────
    switch $mode
        case install
            echo "$c_ok""→ Installing:$c_reset $packages"
            switch $pm
                case paru yay
                    $pm -S $packages
                case pacman
                    sudo pacman -S $packages
                case apt
                    sudo apt install -y $packages
                case dnf
                    sudo dnf install -y $packages
                case zypper
                    sudo zypper install -y $packages
                case brew
                    brew install $packages
                case pkg
                    sudo pkg install -y $packages
                case yum
                    sudo yum install -y $packages
            end

        case uninstall
            echo "$c_warn""→ Removing:$c_reset $packages"
            switch $pm
                case paru yay
                    $pm -Rns $packages
                case pacman
                    sudo pacman -Rns $packages
                case apt
                    sudo apt remove -y $packages
                case dnf
                    sudo dnf remove -y $packages
                case zypper
                    sudo zypper remove -y $packages
                case brew
                    brew uninstall $packages
                case pkg
                    sudo pkg delete -y $packages
                case yum
                    sudo yum remove -y $packages
            end

        case auto
            set -l to_install
            set -l to_remove

            for p in $packages
                if __pkg_is_installed $pm $p
                    set to_remove $to_remove $p
                else
                    set to_install $to_install $p
                end
            end

            if test (count $to_install) -gt 0
                echo "$c_ok""→ Installing:$c_reset $to_install"
                switch $pm
                    case paru yay
                        $pm -S $to_install
                        or begin; functions -e __pkg_is_installed; return $status; end
                    case pacman
                        sudo pacman -S $to_install
                        or begin; functions -e __pkg_is_installed; return $status; end
                    case apt
                        sudo apt install -y $to_install
                        or begin; functions -e __pkg_is_installed; return $status; end
                    case dnf
                        sudo dnf install -y $to_install
                        or begin; functions -e __pkg_is_installed; return $status; end
                    case zypper
                        sudo zypper install -y $to_install
                        or begin; functions -e __pkg_is_installed; return $status; end
                    case brew
                        brew install $to_install
                        or begin; functions -e __pkg_is_installed; return $status; end
                    case pkg
                        sudo pkg install -y $to_install
                        or begin; functions -e __pkg_is_installed; return $status; end
                    case yum
                        sudo yum install -y $to_install
                        or begin; functions -e __pkg_is_installed; return $status; end
                end
            end

            if test (count $to_remove) -gt 0
                echo "$c_warn""→ Removing:$c_reset $to_remove"
                switch $pm
                    case paru yay
                        $pm -Rns $to_remove
                        or begin; functions -e __pkg_is_installed; return $status; end
                    case pacman
                        sudo pacman -Rns $to_remove
                        or begin; functions -e __pkg_is_installed; return $status; end
                    case apt
                        sudo apt remove -y $to_remove
                        or begin; functions -e __pkg_is_installed; return $status; end
                    case dnf
                        sudo dnf remove -y $to_remove
                        or begin; functions -e __pkg_is_installed; return $status; end
                    case zypper
                        sudo zypper remove -y $to_remove
                        or begin; functions -e __pkg_is_installed; return $status; end
                    case brew
                        brew uninstall $to_remove
                        or begin; functions -e __pkg_is_installed; return $status; end
                    case pkg
                        sudo pkg delete -y $to_remove
                        or begin; functions -e __pkg_is_installed; return $status; end
                    case yum
                        sudo yum remove -y $to_remove
                        or begin; functions -e __pkg_is_installed; return $status; end
                end
            end
    end

    functions -e __pkg_is_installed
end
