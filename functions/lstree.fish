# Copyright (C) 2026 Rootiest
# SPDX-License-Identifier: AGPL-3.0-or-later

function lstree --wraps='ls --tree' --description 'alias lstree=ls --tree'
    if which lsd >/dev/null 2>&1
        lsd --tree --hyperlink=auto $argv
    else
        command ls --color=auto -R $argv
    end
end
