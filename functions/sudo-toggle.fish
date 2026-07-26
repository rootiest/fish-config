# Copyright (C) 2026 Rootiest
# SPDX-License-Identifier: AGPL-3.0-or-later

# CATEGORY
#   07-system-and-monitoring
#
# SYNOPSIS
#   sudo-toggle
#
# DESCRIPTION
#   Toggles the sudo NOPASSWD rule on and off via
#   /etc/sudoers.d/nofail-toggle. Useful for automated tasks that would
#   otherwise require a password entry. Clears the sudo credential cache
#   when re-enabling, so the lockdown takes effect immediately.
#
# EXIT STATUS
#   0  Rule toggled
#
# EXAMPLE
#   sudo-toggle
function sudo-toggle --description 'Toggle sudo password requirement on/off'
    # Check the file size using sudo stat to see if our bypass rule is active
    set -l file_size (sudo stat -c %s /etc/sudoers.d/nofail-toggle 2>/dev/null)
    
    if test -n "$file_size"; and test "$file_size" -gt 0
        # 1. Toggle is currently OFF (Bypass is active). We want to turn security back ON.
        # We use 'sudo -k' to clear the execution cache so it locks down instantly.
        sudo -k truncate -s 0 /etc/sudoers.d/nofail-toggle
        echo "🔒 Sudo security: ENABLED (FIDO Key required)"
    else
        # 2. Toggle is currently ON (Security active). We want to BYPASS it.
        # We write a high-priority user-specific NOPASSWD rule.
        echo "$USER ALL=(ALL:ALL) NOPASSWD:ALL" | sudo tee /etc/sudoers.d/nofail-toggle > /dev/null
        echo "🔓 Sudo security: DISABLED (Bypass active)"
    end
end
