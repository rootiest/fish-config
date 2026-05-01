# Copyright (C) 2026 Rootiest
# SPDX-License-Identifier: AGPL-3.0-or-later

# alias rg=rg --hyperlink-format=kitty
function rg --description 'alias rg=rg --hyperlink-format=kitty'
    if test "$TERM" = xterm-kitty
        command rg --hyperlink-format=kitty $argv
    else
        command rg $argv
    end
end
