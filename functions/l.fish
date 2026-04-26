# Copyright (C) 2026 Rootiest
# SPDX-License-Identifier: AGPL-3.0-or-later

function l --wraps='lsd --almost-all --long' --description 'alias l=lsd --almost-all --long'
    if which lsd >/dev/null 2>&1
        lsd --almost-all --long --git --header --hyperlink=auto $argv
    else
        command ls --color=auto --almost-all -l $argv
    end
end
