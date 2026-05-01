# Copyright (C) 2026 Rootiest
# SPDX-License-Identifier: AGPL-3.0-or-later

# Inserts the directory path (dirname) of the last argument from the previous command
function __insert_previous_path_head
    # Get the last command tokens
    set -l tokens (string split -n " " -- $history[1])
    
    # If there are tokens, take the last one and strip the 'tail'
    if set -q tokens[-1]
        set -l path_head (dirname -- $tokens[-1])
        # Insert it into the current command line
        commandline -i -- $path_head
    end
end
