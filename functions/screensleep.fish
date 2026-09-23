# Copyright (C) 2026 Rootiest
# SPDX-License-Identifier: AGPL-3.0-or-later

# CATEGORY
#   07-system-and-monitoring
#
# DEPENDENCIES
#   busctl
#
# SYNOPSIS
#   screensleep
#
# DESCRIPTION
#   Turns off the display after a 1-second delay by invoking the KDE
#   PowerDevil "Turn Off Screen" global shortcut via busctl.
#
# EXIT STATUS
#   1  busctl is not installed
#   *  Exit status of busctl otherwise
#
# EXAMPLE
#   screensleep
function screensleep --description 'Turn off the display using KDE PowerDevil'
    __fish_help_header (status current-function) $argv; and return 0

    if not type -q busctl
        echo (set_color red)"Error: busctl is not installed."(set_color normal) >&2
        return 1
    end

    # Optional: 1-second delay to ensure no keystrokes wake it immediately
    sleep 1
    busctl --user call \
        org.kde.kglobalaccel \
        /component/org_kde_powerdevil \
        org.kde.kglobalaccel.Component \
        invokeShortcut s "Turn Off Screen"
end
