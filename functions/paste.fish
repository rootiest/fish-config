# Copyright (C) 2026 Rootiest
# SPDX-License-Identifier: AGPL-3.0-or-later

# CATEGORY
#   09-clipboard
#
# SYNOPSIS
#   paste [args...]
#
# DESCRIPTION
#   Outputs clipboard contents to stdout. Uses wl-paste on Wayland,
#   falls back to xclip on X11.
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
    else
        echo "Error: Neither wl-paste nor xclip found." >&2
        return 1
    end
end
