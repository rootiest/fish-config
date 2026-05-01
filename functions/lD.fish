# Copyright (C) 2026 Rootiest
# SPDX-License-Identifier: AGPL-3.0-or-later

# List directories only
function lD --description 'List directories only'
    if which eza >/dev/null 2>&1
        eza --only-dirs --long --icons --color=auto --hyperlink $argv
    else if which lsd >/dev/null 2>&1
        lsd --only-dirs --long --hyperlink=auto $argv
    else
        command ls --color=auto -d -- */ $argv
    end
end
