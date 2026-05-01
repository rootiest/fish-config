# Copyright (C) 2026 Rootiest
# SPDX-License-Identifier: AGPL-3.0-or-later

# Execute mkdir
function mkdir --description 'Execute mkdir'
    if status is-interactive
        command mkdir -p $argv
    else
        command mkdir $argv
    end
end
