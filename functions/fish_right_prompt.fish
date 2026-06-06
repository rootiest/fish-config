# Copyright (C) 2026 Rootiest
# SPDX-License-Identifier: AGPL-3.0-or-later

# SYNOPSIS
#   fish_right_prompt
#
# DESCRIPTION
#   Renders the right-side prompt showing the active Docker context (in blue,
#   when non-default) and the current timestamp.
#
# EXAMPLE
#   # Rendered automatically by Fish shell; not called directly.
function fish_right_prompt --description 'Execute fish_right_prompt'
    # 1. Docker Context in Blue
    set -l docker_ctx (docker context show 2>/dev/null)
    if test -n "$docker_ctx"; and test "$docker_ctx" != default
        set_color blue
        echo -n "󰡨 $docker_ctx "
        set_color normal
    end

    # 2. Timestamp Logic with Fallback
    set_color brblack
    if type -q __bobthefish_timestamp
        __bobthefish_timestamp
    else
        # Manual fallback format: Wed Feb 11 15:04:28 2026
        date "+%a %b %d %H:%M:%S %Y"
    end
    set_color normal
end
