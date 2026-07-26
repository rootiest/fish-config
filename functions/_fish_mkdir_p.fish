# Copyright (C) 2026 Rootiest
# SPDX-License-Identifier: AGPL-3.0-or-later

# SYNOPSIS
#   _fish_mkdir_p [--path|--tree|--silent] <dir>
#
# DESCRIPTION
#   Creates a directory and all missing parents, then reports what was created.
#   Output mode is configurable: path (default), tree, or silent.
#
# ARGUMENTS
#   -p, --path    Print a single "Created: ~/path/" line (default)
#   -t, --tree    Show a tree view of the newly created hierarchy
#   -s, --silent  Suppress all output
#   dir           The directory path to create
#
# EXIT STATUS
#   0  Directory created or already exists
#   1  No target directory specified or mkdir failed
#
# EXAMPLE
#   _fish_mkdir_p --tree ~/projects/new/subdir
function _fish_mkdir_p --description 'mkdir -p with configurable verbose output'
    set -l mode path
    set -l target

    for _arg in $argv
        switch $_arg
            case -s --silent
                set mode silent
            case -t --tree
                set mode tree
            case -p --path
                set mode path
            case '*'
                set target $_arg
        end
    end

    test -n "$target"; or return 1
    test -d "$target"; and return 0

    # Walk up to find deepest existing ancestor; collect dirs to create (shallowest first).
    set -l to_create
    set -l cursor $target
    while not test -d $cursor
        set -p to_create $cursor
        set -l up (dirname $cursor)
        test "$up" = "$cursor"; and break  # filesystem root guard
        set cursor $up
    end

    mkdir -p $target; or return $status
    test $mode = silent; and return 0

    if test $mode = path
        set -l display (string replace -- "$HOME" "~" $target)"/"
        echo (set_color --bold cyan)"Created directory: "(set_color cyan)"$display"(set_color normal)
        return 0
    end

    # Tree mode: dimmed existing anchor, then cyan new dirs.
    echo (set_color --bold yellow)"Created directories:"(set_color normal)
    set -l anchor (string replace -- "$HOME" "~" $cursor)"/"
    echo (set_color brblack)" $anchor"(set_color normal)
    set -l i 1
    while test $i -le (count $to_create)
        set -l spaces (string repeat -n (math "($i - 1) * 4") " ")
        set -l name (basename $to_create[$i])"/"
        echo (set_color cyan)" $spaces└── $name"(set_color normal)
        set i (math $i + 1)
    end
end
