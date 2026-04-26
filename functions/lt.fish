# Copyright (C) 2026 Rootiest
# SPDX-License-Identifier: AGPL-3.0-or-later

function lt --description 'Tree listing, depth 2'
    if which eza >/dev/null 2>&1
        eza --tree --level=2 --icons --color=auto --hyperlink $argv
    else if which lsd >/dev/null 2>&1
        lsd --tree --depth=2 --hyperlink=auto $argv
    else
        command ls --color=auto -R $argv
    end
end
