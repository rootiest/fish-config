# Copyright (C) 2026 Rootiest
# SPDX-License-Identifier: AGPL-3.0-or-later

# Function for upgrading the system with paru.
# This runs `paru` with the `-Syu` flags to sync, refresh, and upgrade all
# packages, and adds `--no-confirm` to bypass the confirmation prompt.
function upgrade
    paru -Syu --noconfirm
end
