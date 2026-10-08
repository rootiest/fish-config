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
#   gip
#
# DESCRIPTION
#   Fetches and prints both the public IPv4 and IPv6 addresses using
#   icanhazip.com. Shows "Not detected" for any address that times out.
#
# EXIT STATUS
#   0  Network failures print "Not detected" instead of failing
#   1  curl is not installed
#   2  Unexpected argument (takes none)
#
# EXAMPLE
#   gip
function gip --description 'Show all public IP addresses'
    __fish_help_header (status current-function) $argv; and return 0
    __fish_no_args (status current-function) $argv; or return

    if not type -q curl
        __fish_palette
        echo "$c_err"'gip: curl is not installed'"$c_reset" >&2
        return 1
    end

    echo -n "IPv4: "
    curl -4 -s --max-time 2 https://icanhazip.com || echo "Not detected"
    echo -n "IPv6: "
    curl -6 -s --max-time 2 https://icanhazip.com || echo "Not detected"
end
