# Copyright (C) 2026 Rootiest
# SPDX-License-Identifier: AGPL-3.0-or-later

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
# RETURNS
#   0  Clipboard contents printed successfully
#   1  No supported clipboard tool found
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
