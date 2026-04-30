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
