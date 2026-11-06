# Copyright (C) 2026 Rootiest
# SPDX-License-Identifier: AGPL-3.0-or-later

# SYNOPSIS
#   __fish_user_dots_dir
#
# DESCRIPTION
#   Prints the user-dots fish directory: $__fish_user_dots_path when set,
#   else $XDG_CONFIG_HOME/.user-dots/fish, else ~/.config/.user-dots/fish.
#   An empty value counts as unset. Safe in conf.d, which runs before
#   config.fish defaults XDG_CONFIG_HOME. Every caller resolves the path
#   through this function, never inline, so the fallbacks stay in one place.
#
# EXIT STATUS
#   0  Always
function __fish_user_dots_dir --description 'Print the user-dots fish directory'
    if test -n "$__fish_user_dots_path[1]"
        echo $__fish_user_dots_path[1]
    else if test -n "$XDG_CONFIG_HOME[1]"
        echo $XDG_CONFIG_HOME[1]/.user-dots/fish
    else
        echo $HOME/.config/.user-dots/fish
    end
    return 0
end
