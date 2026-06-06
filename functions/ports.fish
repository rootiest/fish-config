# Copyright (C) 2026 Rootiest
# SPDX-License-Identifier: AGPL-3.0-or-later

# SYNOPSIS
#   ports
#
# DESCRIPTION
#   Lists all active TCP listeners on the system using lsof, showing
#   port numbers and addresses without hostname resolution.
#
# EXAMPLE
#   ports
function ports --wraps='sudo' --description 'Show active network listeners'
    sudo lsof -iTCP -sTCP:LISTEN -P -n
end
