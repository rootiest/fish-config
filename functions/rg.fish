# Copyright (C) 2026 Rootiest
# SPDX-License-Identifier: AGPL-3.0-or-later

# CATEGORY
#   01-file-and-directory
#
# COMPONENT
#   aliases/search
#
# SYNOPSIS
#   rg [args...]
#
# DESCRIPTION
#   Wraps ripgrep with --hyperlink-format=kitty when running inside Kitty
#   terminal, enabling clickable file links in search results. Falls back
#   to plain rg on other terminals.
#
# ARGUMENTS
#   args...  Arguments forwarded to ripgrep
#
# EXAMPLE
#   rg "TODO" src/
#   rg "fish_greeting" ~/.config/fish/
#   rg -l "TODO" ~/projects/myapp
function rg --description 'alias rg=rg --hyperlink-format=kitty'
    # Opinionated guard (C1): fall back to bare command rg when disabled.
    if not __fish_config_op_enabled (status current-function)
        command rg $argv
        return $status
    end

    if test "$TERM" = xterm-kitty
        command rg --hyperlink-format=kitty $argv
    else
        command rg $argv
    end
end
