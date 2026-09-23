# Copyright (C) 2026 Rootiest
# SPDX-License-Identifier: AGPL-3.0-or-later

# CATEGORY
#   07-system-and-monitoring
#
# DEPENDENCIES
#   lsof
#
# SYNOPSIS
#   ports
#
# DESCRIPTION
#   Lists all active TCP listeners on the system using lsof, showing
#   port numbers and addresses without hostname resolution.
#
# EXIT STATUS
#   1  lsof is not installed
#   *  Exit status of lsof otherwise
#
# EXAMPLE
#   ports
function ports --wraps='sudo' --description 'Show active network listeners'
    __fish_help_header (status current-function) $argv; and return 0

    if not type -q lsof
        echo (set_color red)"Error: lsof is not installed."(set_color normal) >&2
        return 1
    end

    sudo lsof -iTCP -sTCP:LISTEN -P -n
end
