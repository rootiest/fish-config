# Copyright (C) 2026 Rootiest
# SPDX-License-Identifier: AGPL-3.0-or-later

function p --description 'Put from clipboard'
    # Check for help flag
    if contains -- -h $argv; or contains -- --help $argv
        echo "Usage: p [OPTIONS]"
        echo ""
        echo "Description:"
        echo "  Pastes content from the system clipboard to stdout."
        echo ""
        echo "Examples:"
        echo "  p                Print clipboard content"
        echo "  p > file.txt     Save clipboard to a file"
        echo "  p | grep 'foo'   Pipe clipboard content to another command"
        echo "  cat (p)          Use clipboard content as a filename for cat"
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
