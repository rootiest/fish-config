# Copyright (C) 2026 Rootiest
# SPDX-License-Identifier: AGPL-3.0-or-later

# SYNOPSIS
#   __interactive_history_sub
#
# DESCRIPTION
#   Provides interactive history substitution at the prompt. When the buffer
#   contains old/new, replaces all occurrences of 'old' with 'new' in the last
#   history entry. When the buffer is empty, prepends 'sudo' to the last command.
#
# EXAMPLE
#   # Type "foo/bar" at prompt to replace "foo" with "bar" in the last command.
function __interactive_history_sub
    set -l current_line (commandline -b)
    set -l last_cmd $history[1]
    
    if string match -qr '(.+)/(.+)' -- "$current_line"
        set -l parts (string split '/' -- "$current_line")
        set -l old $parts[1]
        set -l new $parts[2]
        set -l history_index 1
        
        if test (count $parts) -ge 3; and string match -qr '^[1-9][0-9]*$' -- "$parts[3]"
            set history_index $parts[3]
        end
        
        set -l target_cmd $history[$history_index]
        
        if test -n "$target_cmd"
            set -l expanded (string replace -a -- "$old" "$new" "$target_cmd")
            commandline -r "$expanded"
        end
    else
        if test -z "$current_line"
            commandline -r "sudo $last_cmd"
        end
    end
    commandline -f repaint
end
