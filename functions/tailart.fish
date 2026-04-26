# Copyright (C) 2026 Rootiest
# SPDX-License-Identifier: AGPL-3.0-or-later

function tailart --wraps='tailscale file get ~/Pictures/Art/' --description 'alias tailart=tailscale file get ~/Pictures/Art/'
    tailscale file get ~/Pictures/Art/ $argv
end
