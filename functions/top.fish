# Copyright (C) 2026 Rootiest
# SPDX-License-Identifier: AGPL-3.0-or-later

# SYNOPSIS
#   top [args...]
#
# DESCRIPTION
#   Wraps btop as a modern replacement for top. Falls back to system top
#   if btop is not installed.
#
# ARGUMENTS
#   args...  Arguments forwarded to btop or system top
#
# EXAMPLE
#   top
function top --wraps='btop' --description 'Use btop as a modern replacement for top'
    # 1. Check if btop is actually installed
    if type -q btop
        # 2. Launch btop with any arguments passed
        btop $argv
    else
        # 3. Fallback to the original system top if btop is missing
        command top $argv
    end
end
