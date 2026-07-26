# Copyright (C) 2026 Rootiest
# SPDX-License-Identifier: AGPL-3.0-or-later

# CATEGORY
#   07-system-and-monitoring
#
# SYNOPSIS
#   limine-edit
#
# DESCRIPTION
#   Opens /boot/limine.conf in sudoedit, then re-enrolls the config hash,
#   runs CachyOS boot hooks (limine-mkinitcpio), and re-signs all Secure Boot
#   files tracked by sbctl. Combines the edit and sign steps into a single
#   command.
#
# EXAMPLE
#   limine-edit
function limine-edit --description 'Safely edit and re-verify Limine configuration'
    # 1. Open the config with sudoedit
    sudoedit /boot/limine.conf

    # 2. Re-enroll the config hash (This prevents the Checksum Panic)
    echo "Enrolling Limine config..."
    sudo limine-enroll-config

    # 3. Run the CachyOS boot hooks (Updates snapshots/kernel links)
    echo "Running CachyOS boot hooks..."
    sudo limine-mkinitcpio

    # 4. Sign any unsigned files tracked by sbctl
    # 'sbctl sign-all' will re-apply signatures to everything in the database
    echo "Verifying Secure Boot signatures..."
    sudo sbctl sign-all

    echo "✅ Limine config updated and verified. Ready for reboot."
end
