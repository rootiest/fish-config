# Copyright (C) 2026 Rootiest
# SPDX-License-Identifier: AGPL-3.0-or-later

# SYNOPSIS
#   __fzf_inline_picker
#
# DESCRIPTION
#   Opens an interactive fzf session and injects the selected item directly
#   into the command line at the cursor position. Bound to @@ by default.
#   Repaints the prompt after selection or cancellation.
#
# RETURNS
#   0  Always; no-op if fzf is cancelled
#
# EXAMPLE
#   # Press @@ at the command prompt to open fzf and insert the selected item.
function __fzf_inline_picker
    # Open fzf and capture selection
    set -l selection (fzf)

    if test -n "$selection"
        # Injects text instantly at the cursor
        commandline -i (string escape -- $selection)
    end
    # Refresh the line display
    commandline -f repaint
end
