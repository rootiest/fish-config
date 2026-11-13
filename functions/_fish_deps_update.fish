# Copyright (C) 2026 Rootiest
# SPDX-License-Identifier: AGPL-3.0-or-later

# CLASSIFICATION
#   destructive, network
#
# SYNOPSIS
#   _fish_deps_update [-y|--yes] [TOOL...]
#
# DESCRIPTION
#   Updates all currently installed fish shell dependencies using their
#   preferred method. Priority order: cargo, then system PM, then special
#   installers (fzf-update, fisher, pipx). Always updates fisher plugins first.
#
#   Tools with a release installer (gt, gh) are updated the way they were
#   installed: a binary that resolves to ~/.local/bin/<tool> is replaced by
#   the latest verified release, anything else is upgraded through the
#   system package manager under that manager's package name.
#
#   Naming tools restricts the run to those catalog entries (fisher plugins
#   are then left alone); a name that is not in the catalog is a usage
#   error. --yes is accepted for symmetry with install and changes nothing,
#   since update asks no questions of its own.
#
#   Each update command's exit status is checked. A failing update does not
#   stop the run; the failed tools are collected and reported on stderr at
#   the end ("N of M updates failed: ...").
#
# ARGUMENTS
#   -y, --yes  Accepted and ignored
#   TOOL       Only update these catalog entries
#
# EXIT STATUS
#   0  Every attempted update succeeded, or there was nothing to update
#   1  One or more updates failed
#   2  Unknown option, or a TOOL that is not in the catalog
#
# EXAMPLE
#   _fish_deps_update
#   _fish_deps_update gt gh
function _fish_deps_update
    _fish_deps_catalog
    __fish_palette

    set -l selected
    set -l unknown
    for arg in $argv
        switch $arg
            case -y --yes
            case '-*'
                echo "$c_err""fish-deps: unknown option '$arg'$c_reset" >&2
                echo "Run $c_cmd""fish-deps help$c_reset for usage." >&2
                return 2
            case '*'
                if contains -- $arg $_fdc_bins
                    contains -- $arg $selected; or set -a selected $arg
                else
                    set -a unknown $arg
                end
        end
    end
    if set -q unknown[1]
        echo "$c_err""fish-deps: not in the catalog: "(string join ', ' -- $unknown)"$c_reset" >&2
        echo "Run $c_cmd""fish-deps status$c_reset to list the catalog, or $c_cmd""fish-deps help$c_reset for usage." >&2
        return 2
    end

    set -l pm (_fish_deps_detect_pm)
    set -l attempted 0
    set -l failed

    # Fisher plugins — always update if fisher is present, unless the run
    # was restricted to named tools.
    if type -q fisher; and not set -q selected[1]
        echo "Updating fisher plugins..."
        set attempted (math $attempted + 1)
        fisher update
        or set -a failed fisher
    end

    set -l i 1
    for bin in $_fdc_bins
        # Skip tools that were not named, when some were.
        if set -q selected[1]; and not contains -- $bin $selected
            set i (math $i + 1)
            continue
        end

        # Skip fisher itself (handled above) and tools that aren't installed.
        # command -q (not type -q): ignore wrapper functions shadowing the name.
        if test "$bin" = fisher; or not command -q $bin
            if set -q selected[1]; and test "$bin" != fisher
                echo -n (__fish_color brblack)
                echo "  $bin is not installed — run fish-deps install $bin"
                echo -n (__fish_color normal)
            end
            set i (math $i + 1)
            continue
        end

        set -l cargo_crate $_fdc_cargo[$i]
        set -l pm_pkg $_fdc_pm[$i]
        set -l special $_fdc_special[$i]

        # yay: update via paru if available, else system PM
        if test "$special" = yay-build
            if type -q paru
                echo "Updating $bin..."
                set attempted (math $attempted + 1)
                paru -S --noconfirm yay
                or set -a failed $bin
            else if test -n "$pm_pkg"; and test -n "$pm"
                echo "Updating $bin..."
                set attempted (math $attempted + 1)
                _fish_deps_pm_upgrade $pm_pkg
                or set -a failed $bin
            end
            set i (math $i + 1)
            continue
        end

        # cargo: update via rustup
        if test "$special" = rustup-installer
            if type -q rustup
                echo "Updating $bin..."
                set attempted (math $attempted + 1)
                rustup update
                or set -a failed $bin
            end
            set i (math $i + 1)
            continue
        end

        # fzf: always use fzf-update (git-based)
        if test "$special" = fzf-update
            echo "Updating $bin..."
            set attempted (math $attempted + 1)
            fzf-update
            or set -a failed $bin
            set i (math $i + 1)
            continue
        end

        # ov: prefer go install (always fetches latest); fall back to system PM
        if test "$special" = go-ov
            if type -q go
                echo "Updating $bin..."
                set attempted (math $attempted + 1)
                go install github.com/noborus/ov@latest
                or set -a failed $bin
            else if test -n "$pm_pkg"; and test -n "$pm"
                echo "Updating $bin (go unavailable, using system PM)..."
                set attempted (math $attempted + 1)
                _fish_deps_pm_upgrade $pm_pkg
                or set -a failed $bin
            end
            set i (math $i + 1)
            continue
        end

        # lazydocker: re-run the official install/update script
        if test "$special" = curl-lazydocker
            echo "Updating $bin..."
            set attempted (math $attempted + 1)
            _fish_deps_run_script https://raw.githubusercontent.com/jesseduffield/lazydocker/master/scripts/install_update_linux.sh bash
            or set -a failed $bin
            set i (math $i + 1)
            continue
        end

        # marktext: AUR where it exists, else refresh the AppImage. Only an
        # AppImage we own is refreshed -- a distro-packaged marktext belongs
        # to that package manager, and ~/.local/bin/marktext would shadow it.
        if test "$special" = marktext-release
            if type -q paru
                echo "Updating $bin..."
                set attempted (math $attempted + 1)
                paru -S --noconfirm marktext-bin
                or set -a failed $bin
            else if type -q yay
                echo "Updating $bin..."
                set attempted (math $attempted + 1)
                yay -S --noconfirm marktext-bin
                or set -a failed $bin
            else if test -f "$HOME/.local/bin/marktext"
                echo "Updating $bin..."
                set attempted (math $attempted + 1)
                _fish_deps_marktext_appimage
                or set -a failed $bin
            end
            set i (math $i + 1)
            continue
        end

        # wakatime: re-download the binary from github releases
        if test "$special" = wakatime-binary
            echo "Updating $bin..."
            set attempted (math $attempted + 1)
            _fish_deps_wakatime_binary
            or set -a failed $bin
            set i (math $i + 1)
            continue
        end

        # win32yank: reinstall the pinned, checksum-verified release (WSL2
        # only; only reached if a copy is already on PATH, so no WSL check
        # needed)
        if test "$special" = win32yank-release
            echo "Updating $bin..."
            set attempted (math $attempted + 1)
            _fish_deps_win32yank_binary
            or set -a failed $bin
            set i (math $i + 1)
            continue
        end

        # gt, gh: a copy fish-deps installed from a release lives in
        # ~/.local/bin and is refreshed from the latest release; a packaged
        # copy belongs to its package manager, under that manager's name.
        if contains -- "$special" gt-release gh-release
            if test (command -s $bin) = "$HOME/.local/bin/$bin"
                echo "Updating $bin..."
                set attempted (math $attempted + 1)
                if test $special = gt-release
                    _fish_deps_gt_binary
                else
                    _fish_deps_gh_binary
                end
                or set -a failed $bin
            else if test -n "$pm"; and test -n "$pm_pkg"
                set -l pkg (_fish_deps_pm_pkg $pm $pm_pkg)
                if test -n "$pkg"
                    echo "Updating $bin..."
                    set attempted (math $attempted + 1)
                    _fish_deps_pm_upgrade $pkg
                    or set -a failed $bin
                end
            end
            set i (math $i + 1)
            continue
        end

        # pipx tools
        if test "$special" = pipx
            if type -q pipx
                echo "Updating $bin..."
                set attempted (math $attempted + 1)
                pipx upgrade $bin
                or set -a failed $bin
            end
            set i (math $i + 1)
            continue
        end

        # uv: use built-in self-updater
        if test "$special" = curl-uv
            echo "Updating $bin..."
            set attempted (math $attempted + 1)
            uv self update
            or set -a failed $bin
            set i (math $i + 1)
            continue
        end

        # fish: prefer build from source via git + cargo; fall back to PM
        if test "$special" = git-cargo-fish
            if type -q cargo; and type -q uv
                echo "Updating $bin..."
                set attempted (math $attempted + 1)
                if _fish_deps_build_fish
                    echo -n (__fish_color yellow)
                    echo "  Fish updated — restart your shell to use the new version."
                    echo -n (__fish_color normal)
                else
                    set -a failed $bin
                end
            else if test -n "$pm_pkg"; and test -n "$pm"
                echo "Updating $bin (cargo/uv unavailable, using system PM)..."
                set attempted (math $attempted + 1)
                if _fish_deps_pm_upgrade $pm_pkg
                    echo -n (__fish_color yellow)
                    echo "  Fish updated — restart your shell to use the new version."
                    echo -n (__fish_color normal)
                else
                    set -a failed $bin
                end
            else
                echo -n (__fish_color yellow)
                echo "  fish: cannot update — install cargo and uv to build from source"
                echo -n (__fish_color normal)
            end
            set i (math $i + 1)
            continue
        end

        # curl-installer tools (starship etc.): re-run install script, which upgrades in place
        if test "$special" = curl-installer
            if test "$bin" = starship
                echo "Updating $bin..."
                set attempted (math $attempted + 1)
                _fish_deps_run_script https://starship.rs/install.sh sh --yes
                or set -a failed $bin
            end
            set i (math $i + 1)
            continue
        end

        # Cargo: prefer for Rust tools
        if test -n "$cargo_crate"; and type -q cargo
            echo "Updating $bin..."
            set attempted (math $attempted + 1)
            # --locked, as in install: unlocked, eza 0.23.5 fails to build.
            cargo install --locked --force $cargo_crate
            or set -a failed $bin
            set i (math $i + 1)
            continue
        end

        # System PM fallback
        if test -n "$pm_pkg"; and test -n "$pm"
            echo "Updating $bin..."
            set attempted (math $attempted + 1)
            _fish_deps_pm_upgrade $pm_pkg
            or set -a failed $bin
        end

        set i (math $i + 1)
    end

    if test $attempted -eq 0
        echo "Nothing to update."
    end

    # Explicit terminal status: a trailing `if` with no branch taken would
    # resolve $status to 0 whatever happened above.
    if test (count $failed) -gt 0
        echo "$c_err"(count $failed)" of $attempted updates failed: $c_cmd$failed$c_reset" >&2
        return 1
    end
    return 0
end
