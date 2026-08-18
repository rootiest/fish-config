# Copyright (C) 2026 Rootiest
# SPDX-License-Identifier: AGPL-3.0-or-later

# CATEGORY
#   07-system-and-monitoring
#
# COMPONENT
#   aliases/monitor
#
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
    # Opinionated guard (C1): fall back to bare command top when disabled.
    if not __fish_config_op_enabled (status current-function)
        command top $argv
        return $status
    end

    # 1. Check if btop is actually installed
    if type -q btop
        # 2. Launch btop with any arguments passed
        btop $argv
    else
        # 3. Fallback to the original system top if btop is missing
        command top $argv
    end
end
