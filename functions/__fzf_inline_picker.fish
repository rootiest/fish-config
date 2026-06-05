# Copyright (C) 2026 Rootiest
# SPDX-License-Identifier: AGPL-3.0-or-later

# SYNOPSIS
#   __fzf_inline_picker
#
# DESCRIPTION
#   Opens an interactive fzf session and injects the selected item directly
#   into the command line at the cursor position. Bound to @@ by default.
#   Requires fzf to be installed. Repaints the prompt after insertion.
#
# RETURNS
#   0  A selection was made and inserted into the command line
#   0  No selection was made (fzf cancelled); command line is unchanged
#
# EXAMPLE
#   # Press @@ at the prompt — fzf opens, pick an item, it appears at cursor
#
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
