# Copyright (C) 2026 Rootiest
# SPDX-License-Identifier: AGPL-3.0-or-later

# CATEGORY
#   07-system-and-monitoring
#
# SYNOPSIS
#   ports
#
# DESCRIPTION
#   Lists all active TCP listeners on the system using lsof, showing
#   port numbers and addresses without hostname resolution.
#
# EXIT STATUS
#   Exit status of lsof
#
# EXAMPLE
#   ports
function ports --wraps='sudo' --description 'Show active network listeners'
    __fish_help_header (status current-function) $argv; and return 0

    sudo lsof -iTCP -sTCP:LISTEN -P -n
end
