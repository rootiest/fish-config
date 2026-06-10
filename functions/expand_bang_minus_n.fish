# Execute expand_bang_minus_n
function expand_bang_minus_n --description 'Execute expand_bang_minus_n'
    # Opinionated guard (C3): no expansion when overrides are disabled.
    __fish_config_op_enabled __fish_config_op_overrides; or return 1

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
