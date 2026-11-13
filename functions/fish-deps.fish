# Copyright (C) 2026 Rootiest
# SPDX-License-Identifier: AGPL-3.0-or-later

# CATEGORY
#   06-dependency-management
#
# DEPENDENCIES
#   _fish_deps_status, _fish_deps_install, _fish_deps_update
#
# SYNOPSIS
#   fish-deps [status|install|update|sync|help] [--optional] [--terminals] [--all] [--yes] [TOOL...]
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
#   gt and gh come from the system package manager where it has them; the
#   latest upstream release, verified against the SHA-256 digest published
#   with it, is offered as the alternative and installed to ~/.local/bin.
#   update refreshes a copy installed that way from the latest release, and
#   leaves a packaged copy to the package manager.
#
#   What install does: it walks the catalog and, for each tool that is
#   missing, asks Install <tool>? [Y/n/q]. Enter or y installs it, n skips
#   that tool, and q (or Ctrl+C or Ctrl+D) stops the whole run, so nothing
#   further is offered. Nothing is installed without your say-so, and sudo
#   asks for its own password where the system package manager needs it.
#   Tools it installs are put on this shell's PATH straight away; only fish
#   itself needs a restart to take effect.
#
#   Naming tools after install, update or sync restricts the run to those
#   catalog entries, whatever their tier: fish-deps install kitty offers
#   kitty without --terminals. A name that is not in the catalog is a usage
#   error (exit 2), reported before anything is done.
#
#   For scripts, --yes answers every fish-deps prompt with its default
#   without reading input: each tool is installed through its first
#   (preferred) method, falling back to the next method in the list when
#   one fails, and prerequisites are installed when a method needs them.
#   Prompts that belong to other programs, such as sudo's password,
#   still appear. A bootstrap script can run
#   fish -c 'fish-deps install --yes gt' unattended.
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
#     Required            fish, fzf
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
#     Integrations        wakatime, tailscale, gt, gh
#
# ARGUMENTS
#   status       Report installed/missing deps (default)
#   install      Install missing deps interactively
#   update       Update all installed deps
#   sync         Install missing deps, then update all
#   --optional   With install/sync: also offer Optional-tier deps
#   --terminals  With install/sync: also offer Terminal-Emulator-tier deps
#   --all        With install/sync: shorthand for --optional --terminals
#   -y, --yes    With install/sync: take every default without asking
#   TOOL         With install/update/sync: only these catalog entries
#   help, -h, --help  Show this help
#
# EXIT STATUS
#   0    Subcommand completed, or help was shown
#   1    install had one or more failed installs, or update (or the update
#        half of sync) had one or more failed updates
#   2    Unknown subcommand or option, or a TOOL that is not in the catalog
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
#   fish-deps install gh
#   fish-deps install --yes gt
#   fish-deps update
#   fish-deps update gt gh
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
            _fish_deps_update $flags
            return $status
        case sync
            echo "=== Installing missing deps ==="
            _fish_deps_install $flags
            set -l install_status $status
            # A cancelled install must not roll straight into an update, and
            # a usage error has already been reported.
            test $install_status -eq 130; and return 130
            test $install_status -eq 2; and return 2
            echo ""
            echo "=== Updating installed deps ==="
            # The update half gets the named tools only: the tier flags and
            # --yes mean nothing to it.
            _fish_deps_update (string match -v -- '-*' $flags)
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
    echo "  $c_cmd""fish-deps$c_reset $c_arg""[status]$c_reset            Check installed/missing deps (default)"
    echo "  $c_cmd""fish-deps$c_reset install $c_dim""[TOOL...]$c_reset   Install missing deps interactively (Y/n/q at each prompt)"
    echo "  $c_cmd""fish-deps$c_reset update $c_dim""[TOOL...]$c_reset    Update installed deps"
    echo "  $c_cmd""fish-deps$c_reset sync $c_dim""[TOOL...]$c_reset      Install missing, then update"
    echo "  $c_cmd""fish-deps$c_reset help                Show this help (also -h, --help)"
    echo ""
    echo "  install/sync accept:"
    echo "    $c_flag--optional$c_reset   Also offer Optional-tier deps (skipped by default)"
    echo "    $c_flag--terminals$c_reset  Also offer Terminal-Emulator-tier deps (skipped by default)"
    echo "    $c_flag--all$c_reset        Shorthand for --optional --terminals"
    echo "    $c_flag-y$c_reset, $c_flag--yes$c_reset    Take every default without asking (for scripts);"
    echo "                 a failed method falls back to the next one; prompts from"
    echo "                 sudo or an installer's own script still appear"
    echo ""
    echo "  $c_dim""TOOL$c_reset names restrict a run to those catalog entries, any tier; an"
    echo "  unknown name is a usage error. Example: $c_cmd""fish-deps install --yes gt$c_reset"
    echo ""
    echo "Install method priority: cargo > system PM > git/curl/pipx/release download"
    echo "When multiple methods are available, you will be prompted to choose."
    echo "Answer q (or press Ctrl+C / Ctrl+D) to stop an install run."
end
