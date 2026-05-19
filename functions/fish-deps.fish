# Copyright (C) 2026 Rootiest
# SPDX-License-Identifier: AGPL-3.0-or-later

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
