# Copyright (C) 2026 Rootiest
# SPDX-License-Identifier: AGPL-3.0-or-later

# SYNOPSIS
#   __fzf_inline_picker
#
# DESCRIPTION
#   Bound to the @ key. Self-inserts @ normally; on a second consecutive @
#   (detected by looking behind at the current token rather than making fish
#   buffer ahead for a chord), opens an interactive fzf session listing both
#   files and directories under the current directory, with a preview pane
#   (bat-highlighted for text, image-rendered for pictures via
#   _fzf_preview_file), and replaces the bare @ with the selected item.
#   Cancelling leaves a literal @@ behind. Repaints the prompt after
#   selection or cancellation.
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
        # Directly use fd binary to avoid output buffering delay caused by a fd
        # alias, if any. Debian-based distros install fd as fdfind.
        set -f fd_cmd (command -v fdfind || command -v fd || echo "fd")
        set -f --append fd_cmd --color=always $fzf_fd_opts

        set -l selection ($fd_cmd 2>/dev/null | _fzf_wrapper --ansi \
            --height=90% \
            --layout=reverse \
            --border=rounded \
            --border-label=' Insert Path ' \
            --prompt='@@ -> ' \
            --header='Enter: Insert  Ctrl-/: Toggle Preview  Esc: Cancel' \
            --bind='ctrl-/:toggle-preview' \
            --preview='_fzf_preview_file {}' \
            --preview-window='right:50%:wrap:border-left')

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
