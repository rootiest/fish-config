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
# DEPENDENCIES
#   _fish_clipboard_paste
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
    _fish_clipboard_paste $argv
end
