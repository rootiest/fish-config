# Copyright (C) 2026 Rootiest
# SPDX-License-Identifier: AGPL-3.0-or-later

# SYNOPSIS
#   __insert_previous_path_head
#
# DESCRIPTION
#   Inserts the directory component (dirname) of the last argument from the
#   previous history command into the current commandline. Used as a keybinding
#   helper to quickly reuse a directory path.
#
# EXAMPLE
#   # Bind to a key to insert the directory from the last command.
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
