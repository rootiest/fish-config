# Copyright (C) 2026 Rootiest
# SPDX-License-Identifier: AGPL-3.0-or-later

# CATEGORY
#   08-terminal-management
#
# SYNOPSIS
#   split [-h | -v] [command...]
#
# DESCRIPTION
#   Opens a new pane split in Kitty or WezTerm, optionally running a
#   command in it. Defaults to a horizontal (bottom) split. The new pane
#   inherits the current working directory.
#
# ARGUMENTS
#   -h, --horizontal  Open a horizontal split (default)
#   -v, --vertical    Open a vertical split
#   command...        Command to run in the new pane; opens a bare fish
#                     shell if omitted
#
# RETURNS
#   0  Pane opened successfully
#   1  Not running inside Kitty or WezTerm
#
# EXAMPLE
#   split
#   split -v nvim README.md
function split --description 'Run a command in a new terminal split'
    # Opinionated guard (C4): integrations disabled
    if not __fish_config_op_enabled __fish_config_op_integrations
        set -l c_err (set_color red)
        set -l c_reset (set_color normal)
        echo "$c_err"'split: disabled by __fish_config_op_integrations'"$c_reset" >&2
        return 1
    end

    set -l is_kitty 0
    set -l is_wezterm 0

    if test "$TERM" = xterm-kitty
        set is_kitty 1
    else if test "$TERM_PROGRAM" = WezTerm
        set is_wezterm 1
    else
        echo "Error: The 'split' command requires Kitty or WezTerm terminal." >&2
        return 1
    end

    set -l kitty_loc hsplit
    set -l wez_loc --bottom

    switch $argv[1]
        case -h --horizontal
            set kitty_loc hsplit
            set wez_loc --bottom
            set -e argv[1]
        case -v --vertical
            set kitty_loc vsplit
            set wez_loc --right
            set -e argv[1]
    end

    if test (count $argv) -gt 0
        if test $is_kitty -eq 1
            kitty @ launch --location=$kitty_loc --cwd=$PWD env HIDE_GREETING=1 fish -c "$argv; exec fish"
        else if test $is_wezterm -eq 1
            wezterm cli split-pane $wez_loc --cwd $PWD -- env HIDE_GREETING=1 fish -c "$argv; exec fish" >/dev/null
        end
    else
        if test $is_kitty -eq 1
            kitty @ launch --location=$kitty_loc --cwd=$PWD env HIDE_GREETING=1 fish -c "exec fish"
        else if test $is_wezterm -eq 1
            wezterm cli split-pane $wez_loc --cwd $PWD -- env HIDE_GREETING=1 fish -c "exec fish" >/dev/null
        end
    end
end
