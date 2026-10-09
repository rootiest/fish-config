# Copyright (C) 2026 Rootiest
# SPDX-License-Identifier: AGPL-3.0-or-later

# CATEGORY
#   10-network
#
# DEPENDENCIES
#   curl
#
# CLASSIFICATION
#   network
#
# SYNOPSIS
#   gip4
#
# DESCRIPTION
#   Fetches and prints the machine's public IPv4 address using icanhazip.com.
#
# EXIT STATUS
#   1  curl is not installed
#   2  Unexpected argument (takes none)
#   *  Exit status of curl otherwise
#
# EXAMPLE
#   gip4
function gip4 --wraps='curl' --description 'Get public IPv4 address'
    __fish_help_header (status current-function) $argv; and return 0
    __fish_no_args (status current-function) $argv; or return

    if not type -q curl
        __fish_palette
        echo "$c_err"'gip4: curl is not installed'"$c_reset" >&2
        return 1
    end

    curl -4 -s https://icanhazip.com
end
