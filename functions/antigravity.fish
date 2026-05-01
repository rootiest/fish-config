# Copyright (C) 2026 Rootiest
# SPDX-License-Identifier: AGPL-3.0-or-later

# alias antigravity=antigravity
function antigravity --wraps='antigravity' --description 'alias antigravity=antigravity'
    # In fish, we pipe stderr using '2>|' to another command
    command antigravity $argv 2>| grep -v "'app' is not in the list of known options" >&2
end
