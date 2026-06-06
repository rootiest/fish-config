# Copyright (C) 2026 Rootiest
# SPDX-License-Identifier: AGPL-3.0-or-later

# SYNOPSIS
#   upgrade
#
# DESCRIPTION
#   Runs a full system upgrade via paru or yay with --noconfirm. Falls
#   back to yay if paru is not installed.
#
# RETURNS
#   0  Upgrade completed successfully
#   1  No AUR helper (paru or yay) found
#
# EXAMPLE
#   upgrade
function upgrade --description 'Full system upgrade via paru or yay'
    set -l aur ""
    if type -q paru
        set aur paru
    else if type -q yay
        set aur yay
    else
        echo "No AUR helper found (install paru or yay)" >&2
        return 1
    end
    $aur -Syu --noconfirm
end
