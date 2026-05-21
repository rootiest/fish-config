# Copyright (C) 2026 Rootiest
# SPDX-License-Identifier: AGPL-3.0-or-later

# alias antigravity=agy
function antigravity --wraps='agy' --description 'alias antigravity=agy'
    # In fish, we pipe stderr using '2>|' to another command
    command agy $argv 2>| grep -v "'app' is not in the list of known options" >&2
end
