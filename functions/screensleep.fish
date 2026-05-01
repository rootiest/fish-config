# Copyright (C) 2026 Rootiest
# SPDX-License-Identifier: AGPL-3.0-or-later

# Turn off the display using KDE PowerDevil
function screensleep --description 'Turn off the display using KDE PowerDevil'
    # Optional: 1-second delay to ensure no keystrokes wake it immediately
    sleep 1
    busctl --user call \
        org.kde.kglobalaccel \
        /component/org_kde_powerdevil \
        org.kde.kglobalaccel.Component \
        invokeShortcut s "Turn Off Screen"
end
