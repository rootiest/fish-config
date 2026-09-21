# Copyright (C) 2026 Rootiest
# SPDX-License-Identifier: AGPL-3.0-or-later

# CATEGORY
#   09-clipboard
#
# SYNOPSIS
#   y [text...]
#
# DESCRIPTION
#   Copies text to the system clipboard using wl-copy (Wayland), xclip (X11),
#   or win32yank (WSL2). Reads from stdin when no arguments are given.
#
# DEPENDENCIES
#   _fish_clipboard_copy
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
        __fish_palette
        echo "$c_head""Usage:$c_reset $c_cmd""y$c_reset $c_arg""[TEXT]$c_reset or $c_arg""[COMMAND]$c_reset | $c_cmd""y$c_reset"
        echo ""
        echo "$c_head""Examples:$c_reset"
        echo "  $c_cmd""y$c_reset \"hello world\"    "$c_dim"Copy a string directly"$c_reset
        echo "  ls | $c_cmd""y$c_reset             "$c_dim"Copy output of a command"$c_reset
        echo "  $c_cmd""y$c_reset < file.txt       "$c_dim"Copy contents of a file"$c_reset
        echo "  cat file.txt | $c_cmd""y$c_reset   "$c_dim"Another way to copy a file"$c_reset
        return 0
    end

    # Handle input
    if set -q argv[1]
        # If arguments are provided, echo them to the clipboard
        echo $argv | _fish_clipboard_copy
    else
        # If no arguments, read from stdin (pipes/redirects)
        _fish_clipboard_copy
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
