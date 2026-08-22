# Copyright (C) 2026 Rootiest
# SPDX-License-Identifier: AGPL-3.0-or-later

# CATEGORY
#   09-clipboard
#
# SYNOPSIS
#   p [args...]
#
# DESCRIPTION
#   Outputs clipboard contents to stdout. Uses wl-paste on Wayland,
#   falls back to xclip on X11. Supports -h/--help for usage info.
#
# ARGUMENTS
#   -h, --help  Show usage help
#   args...     Arguments forwarded to the clipboard tool
#
# EXIT STATUS
#   0  Clipboard contents read successfully
#   1  No supported clipboard tool found
#
# RETURNS
#   The clipboard contents, printed to stdout
#
# EXAMPLE
#   p | grep foo
#   p > file.txt
function p --description 'Put from clipboard'
    # Check for help flag
    if contains -- -h $argv; or contains -- --help $argv
        set -l c_head (set_color --bold cyan)
        set -l c_cmd (set_color --bold)
        set -l c_flag (set_color yellow)
        set -l c_dim (set_color brblack)
        set -l c_reset (set_color normal)
        echo "$c_head""Usage:$c_reset $c_cmd""p$c_reset $c_flag""[OPTIONS]$c_reset"
        echo ""
        echo "  Pastes content from the system clipboard to stdout."
        echo ""
        echo "$c_head""Examples:$c_reset"
        echo "  $c_cmd""p$c_reset                "$c_dim"Print clipboard content"$c_reset
        echo "  $c_cmd""p$c_reset > file.txt     "$c_dim"Save clipboard to a file"$c_reset
        echo "  $c_cmd""p$c_reset | grep 'foo'   "$c_dim"Pipe clipboard content to another command"$c_reset
        echo "  cat ($c_cmd""p$c_reset)          "$c_dim"Use clipboard content as a filename for cat"$c_reset
        return 0
    end

    # Determine the clipboard provider
    set -l paste_cmd
    if type -q wl-paste
        set paste_cmd wl-paste
    else if type -q xclip
        set paste_cmd xclip -selection clipboard -o
    else
        echo "Error: No clipboard provider (wl-paste or xclip) found." >&2
        return 1
    end

    # Execute the paste command with any provided arguments
    $paste_cmd $argv
end
