# Copyright (C) 2026 Rootiest
# SPDX-License-Identifier: AGPL-3.0-or-later

# Run a command in a new Kitty split
function split --description 'Run a command in a new Kitty split'
    if test "$TERM" != xterm-kitty
        echo "Error: The 'split' command requires Kitty terminal." >&2
        return 1
    end

    set -l location hsplit

    switch $argv[1]
        case -h --horizontal
            set location hsplit
            set -e argv[1]
        case -v --vertical
            set location vsplit
            set -e argv[1]
    end

    if test (count $argv) -gt 0
        # Set HIDE_GREETING=1 before fish starts
        kitty @ launch --location=$location --cwd=$PWD env HIDE_GREETING=1 fish -c "$argv; exec fish"
    else
        kitty @ launch --location=$location --cwd=$PWD env HIDE_GREETING=1 fish -c "exec fish"
    end
end
