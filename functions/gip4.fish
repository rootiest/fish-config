# Copyright (C) 2026 Rootiest
# SPDX-License-Identifier: AGPL-3.0-or-later

# CATEGORY
#   10-network
#
# SYNOPSIS
#   gip4
#
# DESCRIPTION
#   Fetches and prints the machine's public IPv4 address using icanhazip.com.
#
# EXAMPLE
#   gip4
function gip4 --wraps='curl' --description 'Get public IPv4 address'
    curl -4 -s https://icanhazip.com
end
