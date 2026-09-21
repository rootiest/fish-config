# Copyright (C) 2026 Rootiest
# SPDX-License-Identifier: AGPL-3.0-or-later

# SYNOPSIS
#   _fish_clipboard_paste [args...]
#
# DESCRIPTION
#   Prints the system clipboard contents to stdout. Tries wl-paste
#   (Wayland), then xclip (X11), then win32yank.exe (WSL2).
#
# ARGUMENTS
#   args...  Arguments forwarded to the clipboard tool
#
# EXIT STATUS
#   0  Clipboard contents read successfully
#   1  No clipboard provider found
#
# EXAMPLE
#   _fish_clipboard_paste
function _fish_clipboard_paste --description 'Print the system clipboard contents'
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
