# Execute expand_bang_all
function expand_bang_all --description 'Execute expand_bang_all'
    set -l token $argv[1]
    if test -z "$token"; set token (commandline -t); end
    
    set -l tokens (string split -n " " -- $history[1])
    if test (count $tokens) -gt 1
        echo -- (string join " " -- $tokens[2..-1])
    else
        echo -- $token
    end
end
