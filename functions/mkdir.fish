# Copyright (C) 2026 Rootiest
# SPDX-License-Identifier: AGPL-3.0-or-later

# Execute mkdir
function mkdir --description 'Execute mkdir'
    if status is-interactive
        # Fall back to command mkdir -p when flags are present (e.g. -m 755)
        for _arg in $argv
            if string match -q -- '-*' $_arg
                command mkdir -p $argv
                return $status
            end
        end
        for _dir in $argv
            _fish_mkdir_p --path $_dir
        end
    else
        command mkdir $argv
    end
end
