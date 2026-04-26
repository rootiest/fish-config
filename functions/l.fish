# Copyright (C) 2026 Rootiest
# SPDX-License-Identifier: AGPL-3.0-or-later

function l --description 'Long listing, all files'
    if which eza >/dev/null 2>&1
        eza --all --long --git --header --icons --color=auto --hyperlink $argv
    else if which lsd >/dev/null 2>&1
        lsd --almost-all --long --git --header --hyperlink=auto $argv
    else
        command ls --color=auto --almost-all -l $argv
    end
end
