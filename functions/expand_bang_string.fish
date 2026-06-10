# Execute expand_bang_string
function expand_bang_string --description 'Execute expand_bang_string'
    # Opinionated guard (C3): no expansion when overrides are disabled.
    __fish_config_op_enabled __fish_config_op_overrides; or return 1

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
