# Copyright (C) 2026 Rootiest
# SPDX-License-Identifier: AGPL-3.0-or-later

# Get public IPv4 address
function gip4 --wraps='curl' --description 'Get public IPv4 address'
    curl -4 -s https://icanhazip.com
end
