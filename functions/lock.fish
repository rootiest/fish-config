# Copyright (C) 2026 Rootiest
# SPDX-License-Identifier: AGPL-3.0-or-later

# alias lock=loginctl
function lock --wraps='loginctl' --description 'alias lock=loginctl'
    loginctl lock-session
end
