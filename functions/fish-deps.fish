# Copyright (C) 2026 Rootiest
# SPDX-License-Identifier: AGPL-3.0-or-later

# CATEGORY
#   06-dependency-management
#
# SYNOPSIS
#   fish-deps [status|install|update|sync]
#
# DESCRIPTION
#   Manages fish shell dependencies by dispatching to subcommand handlers.
#   Defaults to status when no subcommand is given.
#
# ARGUMENTS
#   status   Report installed/missing deps (default)
#   install  Install missing deps interactively
#   update   Update all installed deps
#   sync     Install missing deps, then update all
#
# RETURNS
#   0  Subcommand completed
#   1  Unknown subcommand
#
# EXAMPLE
#   fish-deps sync
#   fish-deps
#   fish-deps install
#   fish-deps update
function fish-deps --description 'Manage fish shell dependencies'
    set -l subcmd $argv[1]

    switch $subcmd
        case status ''
            _fish_deps_status
        case install
            _fish_deps_install
        case update
            _fish_deps_update
        case sync
            echo "=== Installing missing deps ==="
            _fish_deps_install
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
    set_color cyan; echo "fish-deps — manage fish shell dependencies"; set_color normal
    echo ""
    echo "Usage:"
    echo "  fish-deps [status]   Check installed/missing deps (default)"
    echo "  fish-deps install    Install missing deps interactively"
    echo "  fish-deps update     Update all installed deps"
    echo "  fish-deps sync       Install missing, then update all"
    echo ""
    echo "Install method priority: cargo > system PM > git/curl/pipx"
    echo "When multiple methods are available, you will be prompted to choose."
end
