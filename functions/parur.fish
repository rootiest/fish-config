# Copyright (C) 2026 Rootiest
# SPDX-License-Identifier: AGPL-3.0-or-later

# Interactively search and remove an installed package using fzf
function parur --description 'Interactively search and remove an installed package using fzf'
    set -l aur ""
    if type -q paru
        set aur paru
    else if type -q yay
        set aur yay
    else
        echo "No AUR helper found (install paru or yay)" >&2
        return 1
    end

    set -l pkg_list (
        pacman -Qqs \
        | fzf --preview 'pacman -Qi {}' --multi
    )

    if test (count $pkg_list) -gt 0
        $aur -R $pkg_list
    else
        echo "No packages selected for removal."
    end
end
