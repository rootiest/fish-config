# Copyright (C) 2026 Rootiest
# SPDX-License-Identifier: AGPL-3.0-or-later

function gip4 -d "Get public IPv4 address"
    curl -4 -s https://icanhazip.com
end
