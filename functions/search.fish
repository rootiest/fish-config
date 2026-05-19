# Copyright (C) 2026 Rootiest
# SPDX-License-Identifier: AGPL-3.0-or-later

function search --description 'Search/install packages interactively via paru or yay'
    set -l aur ""
    if type -q paru
        set aur paru
    else if type -q yay
        set aur yay
    else
        echo "No AUR helper found (install paru or yay)" >&2
        return 1
    end
    $aur $argv
end
