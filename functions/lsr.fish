# Copyright (C) 2026 Rootiest
# SPDX-License-Identifier: AGPL-3.0-or-later

function lsr --description 'Reversed time-sorted listing'
    if which eza >/dev/null 2>&1
        eza --oneline --sort=modified --reverse --icons --color=auto --hyperlink $argv
    else if which lsd >/dev/null 2>&1
        lsd -ltr $argv
    else
        command ls --color=auto -ltr $argv
    end
end
