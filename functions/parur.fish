# Copyright (C) 2026 Rootiest
# SPDX-License-Identifier: AGPL-3.0-or-later

# Interactively search and remove an installed package using fzf
function parur --description 'Interactively search and remove an installed package using fzf'
    # 1. Use command substitution to get the package list from fzf
    set -l pkg_list (
        pacman -Qqs \
        | fzf --preview 'pacman -Qi {}' --multi
    )

    # 2. Check if a package was selected.
    if test (count $pkg_list) -gt 0
        # 3. Pass the selected packages directly to paru -R
        paru -R $pkg_list
    else
        echo "No packages selected for removal."
    end
end
