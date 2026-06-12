# Copyright (C) 2026 Rootiest
# SPDX-License-Identifier: AGPL-3.0-or-later
#
# SYNOPSIS
#   fish_right_prompt
#
# DESCRIPTION
#   Renders the right-side prompt. Shows a red ✘ with the exit code when the
#   last command failed (hidden on success), followed by the current time in
#   Catppuccin Overlay0 (dim). Rendered regardless of C3 state so it pairs
#   correctly with both the starship and the Catppuccin fallback left prompt.
#
# RETURNS
#   0  Always
#
# EXAMPLE
#   # Rendered automatically by fish; not called directly.
function fish_right_prompt --description 'Execute fish_right_prompt'
    set -l last_status $status

    # Failed command: red ✘ + exit code; hidden when 0
    if test $last_status -ne 0
        set_color '#f38ba8'
        echo -n "✘ $last_status  "
        set_color normal
    end

    # Timestamp — Catppuccin Overlay0 (dim)
    set_color '#6c7086'
    date +%X
    set_color normal
end
