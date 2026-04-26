# Copyright (C) 2026 Rootiest
# SPDX-License-Identifier: AGPL-3.0-or-later

function lt --wraps='lsd --tree --depth=2' --description 'alias lt=lsd --tree --depth=2'
    if which lsdq >/dev/null 2>&1
        lsd --tree --depth=2 --hyperlink=auto $argv
    else
        command ls --color=auto -R $argv
    end
end
