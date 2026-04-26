# Copyright (C) 2026 Rootiest
# SPDX-License-Identifier: AGPL-3.0-or-later

function llm --description 'Long listing sorted by modification time'
    if which eza >/dev/null 2>&1
        eza --long --sort=modified --git --header --icons --color=auto --hyperlink $argv
    else if which lsd >/dev/null 2>&1
        lsd --timesort --long --git --header --hyperlink=auto $argv
    else
        command ls --color=auto -lt $argv
    end
end
