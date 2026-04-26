# Copyright (C) 2026 Rootiest
# SPDX-License-Identifier: AGPL-3.0-or-later

function lS --description 'Size-sorted listing'
    if which eza >/dev/null 2>&1
        eza --sort=size --icons --color=auto --hyperlink $argv
    else if which lsd >/dev/null 2>&1
        lsd --oneline --classic $argv
    else
        command ls $argv
    end
end
