# Copyright (C) 2026 Rootiest
# SPDX-License-Identifier: AGPL-3.0-or-later

# Substitutes text in the command line using the ^old^new pattern from the previous command
function __substitute_typo
    set -l cursor_pos (commandline -C)
    set -l cmd (commandline)
    
    # Check if the current line matches the ^old^new pattern
    if string match -qr '\^([^^]+)\^([^^]*)' -- "$cmd"
        set -l last_cmd $history[1]
        set -l captured (string match -r '\^([^^]+)\^([^^]*)' -- "$cmd")
        set -l old $captured[2]
        set -l new $captured[3]
        
        if test -n "$old"
            set -l expanded (string replace -a -- "$old" "$new" "$last_cmd")
            commandline -r "$expanded"
            # No need to move cursor, it's a whole new line
                end
        else
                # If it's just a normal caret (not part of a pattern), just insert it
        commandline -i '^'
    end
end
