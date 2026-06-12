# Copyright (C) 2026 Rootiest
# SPDX-License-Identifier: AGPL-3.0-or-later
#
# SYNOPSIS
#   fish_right_prompt
#
# DESCRIPTION
#   Renders the right-side prompt. Always shows a dim timestamp. When the last
#   command failed, prefixes it with a red ✘ and the exit code. When starship
#   is installed and C3 overrides are enabled, also shows the active Docker
#   context (if non-default) — that block is paired with the starship prompt
#   which already guards on both conditions.
#
# RETURNS
#   0  Always
#
# EXAMPLE
#   # Rendered automatically by fish; not called directly.
function fish_right_prompt
    set -l last_status $status

    # Failed command: red ✘ + exit code; hidden when 0
    if test $last_status -ne 0
        set_color '#f38ba8'
        echo -n "✘ $last_status  "
        set_color normal
    end

    # Docker context — only relevant alongside the starship prompt
    if type -q starship; and __fish_config_op_enabled __fish_config_op_overrides
        set -l docker_ctx (docker context show 2>/dev/null)
        if test -n "$docker_ctx"; and test "$docker_ctx" != default
            set_color blue
            echo -n "󰡨 $docker_ctx "
            set_color normal
        end
    end

    # Timestamp — Catppuccin Overlay0 (dim)
    set_color '#6c7086'
    date "+%a %b %d %H:%M:%S %Y"
    set_color normal
end
