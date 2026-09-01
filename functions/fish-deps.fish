# Copyright (C) 2026 Rootiest
# SPDX-License-Identifier: AGPL-3.0-or-later

# CATEGORY
#   06-dependency-management
#
# SYNOPSIS
#   fish-deps [status|install|update|sync] [--optional] [--terminals] [--all]
#
# DESCRIPTION
#   Unified command for managing all tools this configuration depends on,
#   dispatching to subcommand handlers. Defaults to status when no subcommand
#   is given.
#
#   Install method priority (highest to lowest):
#     1. git+cargo source build (fish shell itself)
#     2. cargo (Rust tools — gets latest crate version)
#     3. system PM (paru/apt/brew/etc.)
#     4. git clone (fzf)
#     5. curl installer (starship, fisher, uv)
#
#   When multiple methods are available you are prompted to choose.
#
#   Dependencies are grouped into five tiers:
#
#     Required           fish, fzf
#     Recommended         cargo, starship, uv, zoxide, direnv, paru, yay,
#                         eza, lsd, bat, ov, ripgrep, trash, python3
#     Optional            btop, dust, duf, prettyping, go, lazygit,
#                         lazydocker, docker, yt-dlp, screen — single-purpose
#                         wrapper conveniences that only matter if you
#                         already use that tool; skipped by install/sync
#                         unless --optional (or --all) is passed
#     Terminal Emulators  kitty, wezterm — only matter if one of them is
#                         your actual terminal; skipped by install/sync
#                         unless --terminals (or --all) is passed
#     Integrations        wakatime, tailscale
#
# ARGUMENTS
#   status       Report installed/missing deps (default)
#   install      Install missing deps interactively
#   update       Update all installed deps
#   sync         Install missing deps, then update all
#   --optional   With install/sync: also offer Optional-tier deps
#   --terminals  With install/sync: also offer Terminal-Emulator-tier deps
#   --all        With install/sync: shorthand for --optional --terminals
#
# EXIT STATUS
#   0  Subcommand completed
#   1  Unknown subcommand
#
# EXAMPLE
#   fish-deps sync
#   fish-deps
#   fish-deps install
#   fish-deps install --optional
#   fish-deps install --terminals
#   fish-deps install --all
#   fish-deps update
function fish-deps --description 'Manage fish shell dependencies'
    set -l subcmd $argv[1]
    set -l flags $argv[2..]

    switch $subcmd
        case status ''
            _fish_deps_status
        case install
            _fish_deps_install $flags
        case update
            _fish_deps_update
        case sync
            echo "=== Installing missing deps ==="
            _fish_deps_install $flags
            echo ""
            echo "=== Updating installed deps ==="
            _fish_deps_update
        case '*'
            set_color red
            echo "Unknown subcommand: $subcmd"
            set_color normal
            echo ""
            __fish_deps_help
            return 1
    end
end

# SYNOPSIS
#   __fish_deps_help
#
# DESCRIPTION
#   Prints usage and subcommand reference for the fish-deps command to stdout.
#
# EXAMPLE
#   __fish_deps_help
function __fish_deps_help
    set -l c_head (set_color --bold cyan)
    set -l c_cmd (set_color --bold)
    set -l c_flag (set_color yellow)
    set -l c_dim (set_color brblack)
    set -l c_reset (set_color normal)

    echo "$c_head""fish-deps$c_reset — manage fish shell dependencies"
    echo ""
    echo "$c_head""Usage:$c_reset"
    echo "  $c_cmd""fish-deps$c_reset $c_dim""[status]$c_reset    Check installed/missing deps (default)"
    echo "  $c_cmd""fish-deps$c_reset install     Install missing deps interactively"
    echo "  $c_cmd""fish-deps$c_reset update      Update all installed deps"
    echo "  $c_cmd""fish-deps$c_reset sync        Install missing, then update all"
    echo ""
    echo "  install/sync accept:"
    echo "    $c_flag--optional$c_reset   Also offer Optional-tier deps (skipped by default)"
    echo "    $c_flag--terminals$c_reset  Also offer Terminal-Emulator-tier deps (skipped by default)"
    echo "    $c_flag--all$c_reset        Shorthand for --optional --terminals"
    echo ""
    echo "Install method priority: cargo > system PM > git/curl/pipx"
    echo "When multiple methods are available, you will be prompted to choose."
end
