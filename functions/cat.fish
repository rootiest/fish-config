# Copyright (C) 2026 Rootiest
# SPDX-License-Identifier: AGPL-3.0-or-later

# alias cat=bat
function cat --wraps='bat' --description 'alias cat=bat'
    if type -q bat
        bat --plain --no-pager $argv
    else
        command cat $argv
    end
end
