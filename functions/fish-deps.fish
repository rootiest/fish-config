# Copyright (C) 2026 Rootiest
# SPDX-License-Identifier: AGPL-3.0-or-later

# CATEGORY
#   06-dependency-management
#
# DEPENDENCIES
#   _fish_deps_status, _fish_deps_install, _fish_deps_update
#
# SYNOPSIS
#   fish-deps [status|install|update|sync|help] [--optional] [--terminals] [--all]
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
#   What install does: it walks the catalog and, for each tool that is
#   missing, asks Install <tool>? [Y/n/q]. Enter or y installs it, n skips
#   that tool, and q (or Ctrl+C or Ctrl+D) stops the whole run, so nothing
#   further is offered. Nothing is installed without your say-so, and sudo
#   asks for its own password where the system package manager needs it.
#   Tools it installs are put on this shell's PATH straight away; only fish
#   itself needs a restart to take effect.
#
#   Prerequisites are offered only once a chosen method needs them: a C
#   compiler for cargo builds (build-essential, base-devel or gcc), a default
#   Rust toolchain when cargo is a bare rustup shim, unzip for the wakatime-cli
#   download, and Go for ov on distros that do not package it. Rust tools are
#   built with cargo install --locked, so they use the dependency versions
#   their authors published rather than whatever is newest. paru and yay are
#   only offered on Arch-based systems.
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
#   help, -h, --help  Show this help
#
# EXIT STATUS
#   0    Subcommand completed, or help was shown
#   1    install had one or more failed installs, or update (or the update
#        half of sync) had one or more failed updates
#   2    Unknown subcommand
#   130  install (or the install half of sync) was cancelled with q, Ctrl+C
#        or Ctrl+D; sync does not go on to update
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
    # Checked before dispatch so `fish-deps install --help` never installs.
    # The menu is richer than the header renderer's, so it stays.
    if test "$argv[1]" = help; or __fish_help_requested $argv
        __fish_deps_help
        return 0
    end

    # -- ends option parsing: what follows is data, never a help request.
    set -l dd (contains -i -- -- $argv); and set -e argv[$dd]
    set -l subcmd $argv[1]
    set -l flags $argv[2..]

    switch $subcmd
        case status ''
            _fish_deps_status
        case install
            _fish_deps_install $flags
            return $status
        case update
            _fish_deps_update
            return $status
        case sync
            echo "=== Installing missing deps ==="
            _fish_deps_install $flags
            set -l install_status $status
            # A cancelled install must not roll straight into an update.
            test $install_status -eq 130; and return 130
            echo ""
            echo "=== Updating installed deps ==="
            _fish_deps_update
            set -l update_status $status
            test $update_status -ne 0; and return $update_status
            return $install_status
        case '*'
            __fish_palette
            echo "$c_err""fish-deps: unknown subcommand '$subcmd'$c_reset" >&2
            echo "Run $c_cmd""fish-deps help$c_reset for usage." >&2
            return 2
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
    __fish_palette

    echo "$c_head""fish-deps$c_reset — manage fish shell dependencies"
    echo ""
    echo "$c_head""Usage:$c_reset"
    echo "  $c_cmd""fish-deps$c_reset $c_arg""[status]$c_reset    Check installed/missing deps (default)"
    echo "  $c_cmd""fish-deps$c_reset install     Install missing deps interactively (Y/n/q at each prompt)"
    echo "  $c_cmd""fish-deps$c_reset update      Update all installed deps"
    echo "  $c_cmd""fish-deps$c_reset sync        Install missing, then update all"
    echo "  $c_cmd""fish-deps$c_reset help        Show this help (also -h, --help)"
    echo ""
    echo "  install/sync accept:"
    echo "    $c_flag--optional$c_reset   Also offer Optional-tier deps (skipped by default)"
    echo "    $c_flag--terminals$c_reset  Also offer Terminal-Emulator-tier deps (skipped by default)"
    echo "    $c_flag--all$c_reset        Shorthand for --optional --terminals"
    echo ""
    echo "Install method priority: cargo > system PM > git/curl/pipx"
    echo "When multiple methods are available, you will be prompted to choose."
    echo "Answer q (or press Ctrl+C / Ctrl+D) to stop an install run."
end
