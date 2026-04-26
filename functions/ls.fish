# Copyright (C) 2026 Rootiest
# SPDX-License-Identifier: AGPL-3.0-or-later

function ls --description 'List files'
    if which eza >/dev/null 2>&1
        eza --oneline --icons --color=auto --hyperlink $argv

    else if which lsd >/dev/null 2>&1
        lsd --hyperlink=auto $argv
    else
        command ls --color=auto $argv
    end
end
