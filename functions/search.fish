# Copyright (C) 2026 Rootiest
# SPDX-License-Identifier: AGPL-3.0-or-later

# CATEGORY
#   05-package-management
#
# SYNOPSIS
#   search [args...]
#
# DESCRIPTION
#   Delegates to paru or yay for interactive AUR package search and
#   installation. Falls back to yay if paru is not installed.
#
# ARGUMENTS
#   args...  Arguments forwarded to paru or yay
#
# RETURNS
#   0  AUR helper ran successfully
#   1  No AUR helper (paru or yay) found
#
# EXAMPLE
#   search neovim
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
