# Execute expand_bang_search
function expand_bang_search --description 'Execute expand_bang_search'
    # Opinionated guard (C3): no expansion when overrides are disabled.
    __fish_config_op_enabled __fish_config_op_overrides; or return 1

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
