# Copyright (C) 2026 Rootiest
# SPDX-License-Identifier: AGPL-3.0-or-later

# alias dusize=du
function dusize --wraps='du' --description 'alias dusize=du'
    du -sh (test -n "$argv[1]"; and echo $argv[1]; or echo .)
end
