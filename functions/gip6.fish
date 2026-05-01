# Copyright (C) 2026 Rootiest
# SPDX-License-Identifier: AGPL-3.0-or-later

# Get public IPv6 address
function gip6 --description 'Get public IPv6 address'
    # Use -6 to force IPv6 and --fail to catch network errors
    set -l ip (curl -6 -s --fail https://icanhazip.com 2>/dev/null)
    
    if test $status -eq 0
        echo $ip
    else
        echo "❌ IPv6 is currently unavailable or not supported on this network."
        return 1
    end
end
