# Copyright (C) 2026 Rootiest
# SPDX-License-Identifier: AGPL-3.0-or-later

function pkg --description 'Install or remove packages via paru or yay'
    # ── AUR helper detection ─────────────────────────────────────
    set -l aur ""
    if type -q paru
        set aur paru
    else if type -q yay
        set aur yay
    else
        set_color red
        echo "error: no AUR helper found (install paru or yay)" >&2
        set_color normal
        return 1
    end

    # ── Colour palette ───────────────────────────────────────────
    set -l c_head (set_color --bold cyan)
    set -l c_cmd (set_color --bold white)
    set -l c_flag (set_color yellow)
    set -l c_ok (set_color green)
    set -l c_warn (set_color yellow)
    set -l c_err (set_color red)
    set -l c_dim (set_color brblack)
    set -l c_reset (set_color normal)

    # ── Help ─────────────────────────────────────────────────────
    function _pkg_help
        echo "$c_head""Usage:$c_reset $c_cmd""pkg$c_reset " \
            "$c_flag""[-h] [-i] [-u]$c_reset $c_dim""<package>...$c_reset"
        echo
        echo "  Install or remove Arch packages via paru/yay."
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
                echo "  Install or remove Arch packages via paru/yay."
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
                return 0
            case -i --install
                set mode install
            case -u --uninstall
                set mode uninstall
            case --
                # stop flag parsing (remaining args handled above)
            case '-*'
                echo "$c_err""error:$c_reset unknown flag $c_flag$arg$c_reset" >&2
                return 1
            case '*'
                set packages $packages $arg
        end
    end

    if test (count $packages) -eq 0
        _pkg_help
        return 0
    end

    # ── Dispatch ─────────────────────────────────────────────────
    switch $mode
        case install
            echo "$c_ok""→ Installing:$c_reset $packages"
            $aur -S $packages

        case uninstall
            echo "$c_warn""→ Removing:$c_reset $packages"
            $aur -Rns $packages

        case auto
            set -l to_install
            set -l to_remove

            for pkg in $packages
                if pacman -Qi $pkg &>/dev/null
                    set to_remove $to_remove $pkg
                else
                    set to_install $to_install $pkg
                end
            end

            if test (count $to_install) -gt 0
                echo "$c_ok""→ Installing:$c_reset $to_install"
                $aur -S $to_install
                or return $status
            end

            if test (count $to_remove) -gt 0
                echo "$c_warn""→ Removing:$c_reset $to_remove"
                $aur -Rns $to_remove
                or return $status
            end
    end
end
