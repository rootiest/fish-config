# Copyright (C) 2026 Rootiest
# SPDX-License-Identifier: AGPL-3.0-or-later

function ls --wraps=lsd --wraps='lsd --hyperlink=auto' --description 'alias ls=lsd'
    if which lsd >/dev/null 2>&1
        lsd --hyperlink=auto $argv
    else
        command ls --color=auto $argv
    end
end
