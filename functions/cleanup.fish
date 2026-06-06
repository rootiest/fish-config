# Copyright (C) 2026 Rootiest
# SPDX-License-Identifier: AGPL-3.0-or-later

# SYNOPSIS
#   cleanup
#
# DESCRIPTION
#   Identifies and removes Arch Linux orphan packages using pacman. Logs
#   package names and versions to ~/.removed_orphans before removal.
#
# EXAMPLE
#   cleanup
function cleanup --description 'Log orphans to ~/.removed_orphans and remove them'
    set -l orphans (pacman -Qtdq)
    if test -n "$orphans"
        echo "📝 Logging orphans to ~/.removed_orphans..."
        echo "--- Removed on $(date) ---" >> ~/.removed_orphans
        pacman -Qi $orphans | grep -E '^(Name|Version)' >> ~/.removed_orphans
        
        echo "🧹 Removing orphans..."
        sudo pacman -Rns $orphans
    else
        echo "✨ No orphans to clean up!"
    end
end
