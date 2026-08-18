# Copyright (C) 2026 Rootiest
# SPDX-License-Identifier: AGPL-3.0-or-later

# CATEGORY
#   05-package-management
#
# COMPONENT
#   integrations/pkg-upgrade
#
# SYNOPSIS
#   upgrade
#
# DESCRIPTION
#   Runs a full system upgrade via paru or yay with --noconfirm. Falls
#   back to yay if paru is not installed. Arch Linux only.
#
# EXIT STATUS
#   0  Upgrade completed successfully
#   1  No AUR helper (paru or yay) found
#
# EXAMPLE
#   upgrade
function upgrade --description 'Full system upgrade via paru or yay'
    # Opinionated guard (C4): integrations disabled
    if not __fish_config_op_enabled (status current-function)
        set -l c_err (set_color red)
        set -l c_reset (set_color normal)
        echo "$c_err"'upgrade: disabled by __fish_config_op_integrations'"$c_reset" >&2
        return 1
    end

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
