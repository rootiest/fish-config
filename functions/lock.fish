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
# EXAMPLE
#   lock
function lock --wraps='loginctl' --description 'alias lock=loginctl'
    loginctl lock-session
end
