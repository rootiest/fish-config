# Copyright (C) 2026 Rootiest
# SPDX-License-Identifier: AGPL-3.0-or-later

# CATEGORY
#   09-clipboard
#
# SYNOPSIS
#   y [text...]
#
# DESCRIPTION
#   Copies text to the system clipboard using wl-copy (Wayland) or xclip (X11).
#   Reads from stdin when no arguments are given.
#
# ARGUMENTS
#   text  Text to copy; reads from stdin if omitted
#
# EXIT STATUS
#   0  Text copied to clipboard
#   1  No clipboard provider found
#
# EXAMPLE
#   y "hello world"
#   ls | y
#   cat file.txt | y
function y --description 'Yank to clipboard'
    # Check for help flag
    if contains -- -h $argv; or contains -- --help $argv
        set -l c_head (set_color --bold cyan)
        set -l c_cmd (set_color --bold)
        set -l c_arg (set_color cyan)
        set -l c_dim (set_color brblack)
        set -l c_reset (set_color normal)
        echo "$c_head""Usage:$c_reset $c_cmd""y$c_reset $c_arg""[TEXT]$c_reset or $c_arg""[COMMAND]$c_reset | $c_cmd""y$c_reset"
        echo ""
        echo "$c_head""Examples:$c_reset"
        echo "  $c_cmd""y$c_reset \"hello world\"    "$c_dim"Copy a string directly"$c_reset
        echo "  ls | $c_cmd""y$c_reset             "$c_dim"Copy output of a command"$c_reset
        echo "  $c_cmd""y$c_reset < file.txt       "$c_dim"Copy contents of a file"$c_reset
        echo "  cat file.txt | $c_cmd""y$c_reset   "$c_dim"Another way to copy a file"$c_reset
        return 0
    end

    # Determine the clipboard provider
    set -l copy_cmd
    if type -q wl-copy
        set copy_cmd wl-copy
    else if type -q xclip
        set copy_cmd xclip -selection clipboard
    else
        echo "Error: No clipboard provider (wl-copy or xclip) found." >&2
        return 1
    end

    # Handle input
    if set -q argv[1]
        # If arguments are provided, echo them to the clipboard
        echo $argv | eval $copy_cmd
    else
        # If no arguments, read from stdin (pipes/redirects)
        eval $copy_cmd
    end
end

# SYNOPSIS
#   cb [text...]
#
# DESCRIPTION
#   Alias for y — copies text to the system clipboard.
#
# ARGUMENTS
#   text  Text to copy; reads from stdin if omitted
#
# EXAMPLE
#   ls | cb
function cb --wraps='y' --description 'Alias cb=y'
    y $argv
end