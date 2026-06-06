# Copyright (C) 2026 Rootiest
# SPDX-License-Identifier: AGPL-3.0-or-later

# SYNOPSIS
#   gip
#
# DESCRIPTION
#   Fetches and prints both the public IPv4 and IPv6 addresses using
#   icanhazip.com. Shows "Not detected" for any address that times out.
#
# EXAMPLE
#   gip
function gip --description 'Show all public IP addresses'
    echo -n "IPv4: "
    curl -4 -s --max-time 2 https://icanhazip.com || echo "Not detected"
    echo -n "IPv6: "
    curl -6 -s --max-time 2 https://icanhazip.com || echo "Not detected"
end
