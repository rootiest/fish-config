# Copyright (C) 2026 Rootiest
# SPDX-License-Identifier: AGPL-3.0-or-later

# SYNOPSIS
#   screensleep
#
# DESCRIPTION
#   Turns off the display after a 1-second delay by invoking the KDE
#   PowerDevil "Turn Off Screen" global shortcut via busctl.
#
# EXAMPLE
#   screensleep
function screensleep --description 'Turn off the display using KDE PowerDevil'
    # Optional: 1-second delay to ensure no keystrokes wake it immediately
    sleep 1
    busctl --user call \
        org.kde.kglobalaccel \
        /component/org_kde_powerdevil \
        org.kde.kglobalaccel.Component \
        invokeShortcut s "Turn Off Screen"
end
