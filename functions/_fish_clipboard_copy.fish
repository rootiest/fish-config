# Copyright (C) 2026 Rootiest
# SPDX-License-Identifier: AGPL-3.0-or-later

# SYNOPSIS
#   _fish_clipboard_copy
#
# DESCRIPTION
#   Copies stdin to the system clipboard. Tries wl-copy (Wayland), then
#   xclip (X11), then win32yank.exe (WSL2).
#
# EXIT STATUS
#   0  Text copied to clipboard
#   1  No clipboard provider found
#
# EXAMPLE
#   echo "hello" | _fish_clipboard_copy
function _fish_clipboard_copy --description 'Copy stdin to the system clipboard'
    if type -q wl-copy
        wl-copy
    else if type -q xclip
        xclip -selection clipboard
    else if type -q win32yank.exe
        win32yank.exe -i --crlf
    else
        echo "Error: No clipboard provider (wl-copy, xclip, or win32yank) found." >&2
        return 1
    end
end
