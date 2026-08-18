# Copyright (C) 2026 Rootiest
# SPDX-License-Identifier: AGPL-3.0-or-later

# COMPONENT
#   overrides/key-bindings

# Provides bash-style history expansion functions for abbreviations.
# These functions are gated by the C3 overrides switch.

# Execute expand_bang_all
function expand_bang_all --description 'Execute expand_bang_all'
    # Opinionated guard (C3): no expansion when overrides are disabled.
    __fish_config_op_enabled (status basename); or return 1

    set -l token $argv[1]
    if test -z "$token"; set token (commandline -t); end
    
    set -l tokens (string split -n " " -- $history[1])
    if test (count $tokens) -gt 1
        echo -- (string join " " -- $tokens[2..-1])
    else
        echo -- $token
    end
end

# Execute expand_bang_caret
function expand_bang_caret --description 'Execute expand_bang_caret'
    # Opinionated guard (C3): no expansion when overrides are disabled.
    __fish_config_op_enabled (status basename); or return 1

    # Split the last history item into a list
    set -l tokens (string split -n ' ' -- $history[1])
    # tokens[1] is the command, tokens[2] is the first argument
    if set -q tokens[2]
        echo -- $tokens[2]
    end
end

# Execute expand_bang_minus_n
function expand_bang_minus_n --description 'Execute expand_bang_minus_n'
    # Opinionated guard (C3): no expansion when overrides are disabled.
    __fish_config_op_enabled (status basename); or return 1

    set -l token $argv[1]
    if test -z "$token"; set token (commandline -t); end
    
    # Extract the number from the regex match
    if string match -qr '!-(\d+)' -- "$token"
        set -l n (string match -r '!-(\d+)' -- "$token")[2]
        
        if test (count $history) -ge $n
            echo -- $history[$n]
        else
            echo -- $token
        end
    else
        echo -- $token
    end
end

# Execute expand_bang_search
function expand_bang_search --description 'Execute expand_bang_search'
    # Opinionated guard (C3): no expansion when overrides are disabled.
    __fish_config_op_enabled (status basename); or return 1

    set -l token $argv[1]
    if test -z "$token"
        set token (commandline -t)
    end
    
    # Extract query: looks for text after !? and before an optional ?
    set -l query (string match -r '!\?([^?]+)' -- $token)[2]
    
    if test -n "$query"
        # Search history for a match anywhere in the command
        set -l match (builtin history search --contains --max=1 -- $query)
        
        if test -n "$match"
            echo -- $match
            return
        end
    end
    
    echo -- $token
end

# Execute expand_bang_string
function expand_bang_string --description 'Execute expand_bang_string'
    # Opinionated guard (C3): no expansion when overrides are disabled.
    __fish_config_op_enabled (status basename); or return 1

    # Fish 4.x passes the matched token as argv[1]
    set -l token $argv[1]
    if test -z "$token"
        set token (commandline -t)
    end
    
    # Remove the '!' to get the search query
    set -l query (string sub -s 2 -- $token)
    
    if test -n "$query"
        # Search history for a prefix match
        set -l match (builtin history search --prefix --max=1 -- $query)
        
        if test -n "$match"
            echo -- $match
            return
        end
    end
    
    # If no match or empty query, return the token so it doesn't vanish
    echo -- $token
end

# Execute expand_typo_sub
function expand_typo_sub --description 'Execute expand_typo_sub'
    # Opinionated guard (C3): no expansion when overrides are disabled.
    __fish_config_op_enabled (status basename); or return 1

    # In newer Fish, the matched token is often passed as $argv[1]
    # if the abbr is set up correctly. We'll fallback to commandline just in case.
    set -l last_cmd $history[1]
    set -l current_token $argv[1]
    if test -z "$current_token"
        set current_token (commandline -t)
    end
    
    if string match -qr '\^([^^]+)\^([^^]*)' -- "$current_token"
        set -l captured (string match -r '\^([^^]+)\^([^^]*)' -- "$current_token")
        set -l old $captured[2]
        set -l new $captured[3]
        
        if test -n "$old"
            # Using -- to ensure strings starting with '-' aren't treated as flags
            echo -- (string replace -a -- "$old" "$new" "$last_cmd")
        end
    else
        # Return the token itself so it doesn't vanish
        echo -- "$current_token"
    end
end
