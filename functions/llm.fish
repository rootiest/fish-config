# Copyright (C) 2026 Rootiest
# SPDX-License-Identifier: AGPL-3.0-or-later

function llm --wraps='lsd --timesort --long' --description 'alias llm=lsd --timesort --long'
    if which lsd >/dev/null 2>&1
        lsd --timesort --long --git --header --hyperlink=auto $argv
    else
        command ls color=auto -l $argv
    end
end
