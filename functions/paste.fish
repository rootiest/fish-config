# Copyright (C) 2026 Rootiest
# SPDX-License-Identifier: AGPL-3.0-or-later

# CATEGORY
#   09-clipboard
#
# SYNOPSIS
#   paste [args...]
#
# DESCRIPTION
#   Outputs clipboard contents to stdout. Uses wl-paste on Wayland, xclip on
#   X11, or win32yank on WSL2.
#
# ARGUMENTS
#   args...  Arguments forwarded to the clipboard tool
#
# EXIT STATUS
#   0  Clipboard contents read successfully
#   1  No supported clipboard tool found
#
# RETURNS
#   The clipboard contents, printed to stdout
#
# EXAMPLE
#   paste > file.txt
function paste --description 'Paste from clipboard'
    if type -q wl-paste
        wl-paste $argv
    else if type -q xclip
        xclip -selection clipboard -o $argv
    else if type -q win32yank.exe
        win32yank.exe -o --lf $argv
    else
        echo "Error: No clipboard provider (wl-paste, xclip, or win32yank) found." >&2
        return 1
    end
end
