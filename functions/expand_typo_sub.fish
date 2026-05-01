# Execute expand_typo_sub
function expand_typo_sub --description 'Execute expand_typo_sub'
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
