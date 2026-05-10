# Copyright (C) 2026 Rootiest
# SPDX-License-Identifier: AGPL-3.0-or-later

# Use bat for files and ls for directories when using cat
function cat --wraps='bat' --description 'Use bat for files and ls for directories'
    # If no arguments are provided, cat usually waits for stdin. 
    # We'll maintain that behavior by skipping the directory check if $argv is empty.
    if set -q argv[1]
        if test -d $argv[1]
            # If it's a directory, run your custom ls function
            ls $argv
            return
        end
    end

    # Fallback to bat or standard cat
    if type -q bat
        bat --plain --no-pager $argv
    else
        command cat $argv
    end
end
