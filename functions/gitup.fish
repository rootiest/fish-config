# Fetch updates and show git status
function gitup --description 'Fetch updates and show git status'
    # Check if we are even in a git repository
    if not git rev-parse --is-inside-work-tree >/dev/null 2>&1
        echo "Check your map! You aren't in a git repository."
        return 1
    end
    
    if count $argv >/dev/null
        git fetch $argv
    else
        git fetch
    end
    
    and git status
end
