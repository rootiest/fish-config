# Copyright (C) 2026 Rootiest
# SPDX-License-Identifier: AGPL-3.0-or-later

# CATEGORY
#   07-system-and-monitoring
#
# DEPENDENCIES
#   loginctl
#
# SYNOPSIS
#   lock
#
# DESCRIPTION
#   Locks the current desktop session using loginctl lock-session.
#
# EXIT STATUS
#   1  loginctl is not installed
#   *  Exit status of loginctl lock-session otherwise
#
# EXAMPLE
#   lock
function lock --wraps='loginctl' --description 'alias lock=loginctl'
    __fish_help_header (status current-function) $argv; and return 0

    if not type -q loginctl
        echo (set_color red)"Error: loginctl is not installed."(set_color normal) >&2
        return 1
    end

    loginctl lock-session
end
