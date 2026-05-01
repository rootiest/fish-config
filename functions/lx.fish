# Copyright (C) 2026 Rootiest
# SPDX-License-Identifier: AGPL-3.0-or-later

# Extension-sorted listing
function lx --description 'Extension-sorted listing'
    if which eza >/dev/null 2>&1
        eza --long --all --sort=extension --icons --color=auto --hyperlink $argv
    else if which lsd >/dev/null 2>&1
        lsd --long --all --sort=extension --hyperlink=auto $argv
    else
        command ls --color=auto -lX $argv
    end
end
