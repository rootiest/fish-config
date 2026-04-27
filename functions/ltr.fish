# Copyright (C) 2026 Rootiest
# SPDX-License-Identifier: AGPL-3.0-or-later

function ltr --description 'Reversed time-sorted listing'
    if which eza >/dev/null 2>&1
        eza --long --all --sort=modified --reverse --icons --hyperlink --color=auto --color-scale=age --color-scale-mode=gradient $argv
    else if which lsd >/dev/null 2>&1
        lsd --long --all --sort=time --reverse --color=auto --hyperlink=always $argv
    else
        command ls --color=auto -ltr $argv
    end
end
