# Copyright (C) 2026 Rootiest
# SPDX-License-Identifier: AGPL-3.0-or-later

# Full recursive tree listing
function lstree --description 'Full recursive tree listing'
    if which eza >/dev/null 2>&1
        eza --tree --icons --color=auto --hyperlink $argv
    else if which lsd >/dev/null 2>&1
        lsd --tree --hyperlink=auto $argv
    else
        command ls --color=auto -R $argv
    end
end
