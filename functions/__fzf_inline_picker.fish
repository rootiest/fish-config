# Copyright (C) 2026 Rootiest
# SPDX-License-Identifier: AGPL-3.0-or-later

# SYNOPSIS
#   __fzf_inline_picker
#
# DESCRIPTION
#   Bound to the @ key. Self-inserts @ normally; on a second consecutive @
#   (detected by looking behind at the current token rather than making fish
#   buffer ahead for a chord), opens an interactive fzf session and replaces
#   the bare @ with the selected item. Cancelling leaves a literal @@ behind.
#   Repaints the prompt after selection or cancellation.
#
# EXIT STATUS
#   0  Always
#
# EXAMPLE
#   # Press @ twice at the command prompt to open fzf and insert the
#   # selected item in place of the second @, then keep typing to extend it
#   # (e.g. a trailing /subdir).
function __fzf_inline_picker
    if test (commandline -t) = @
        set -l selection (fzf)
        if test -n "$selection"
            commandline -t -- (string escape -- $selection)
        else
            commandline -t -- @@
        end
        commandline -f repaint
    else
        commandline -i @
    end
end
