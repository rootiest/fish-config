# Copyright (C) 2026 Rootiest
# SPDX-License-Identifier: AGPL-3.0-or-later

function ltr --wraps='lsd -ltr' --description 'alias ltr=lsd -ltr'
    lsd -ltr $argv
end
