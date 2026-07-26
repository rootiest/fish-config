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
        echo "Usage: y [TEXT] or [COMMAND] | y"
        echo ""
        echo "Examples:"
        echo "  y \"hello world\"    Copy a string directly"
        echo "  ls | y             Copy output of a command"
        echo "  y < file.txt       Copy contents of a file"
        echo "  cat file.txt | y   Another way to copy a file"
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