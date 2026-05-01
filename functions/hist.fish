# Copyright (C) 2026 Rootiest
# SPDX-License-Identifier: AGPL-3.0-or-later

# Search fish history and put it in the prompt
function hist --description 'Search fish history and put it in the prompt'
    set -l selected (history | fzf --reverse --height 40% --with-nth 3..)

    if test -n "$selected"
        # Strip the timestamp for the final output
        set -l command (echo $selected | string replace -r '^\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2} ' '')
        
        echo $command | wl-copy 2>/dev/null
        commandline -r $command
    end
end
