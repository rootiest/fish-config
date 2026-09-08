# Copyright (C) 2026 Rootiest
# SPDX-License-Identifier: AGPL-3.0-or-later

# CATEGORY
#   07-system-and-monitoring
#
# SYNOPSIS
#   lock
#
# DESCRIPTION
#   Locks the current desktop session using loginctl lock-session.
#
# EXIT STATUS
#   Exit status of `loginctl lock-session`
#
# EXAMPLE
#   lock
function lock --wraps='loginctl' --description 'alias lock=loginctl'
    __fish_help_header (status current-function) $argv; and return 0

    loginctl lock-session
end
