# Copyright (C) 2026 Rootiest
# SPDX-License-Identifier: AGPL-3.0-or-later

function lS --wraps='lsd --oneline --classic' --description 'alias lS=lsd --oneline --classic'
    if which lsd >/dev/null 2>&1
        lsd --oneline --classic $argv
    else
        command ls $argv
    end
end
