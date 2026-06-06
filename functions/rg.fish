# Copyright (C) 2026 Rootiest
# SPDX-License-Identifier: AGPL-3.0-or-later

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
function rg --description 'alias rg=rg --hyperlink-format=kitty'
    if test "$TERM" = xterm-kitty
        command rg --hyperlink-format=kitty $argv
    else
        command rg $argv
    end
end
