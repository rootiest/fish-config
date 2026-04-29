function branch --description 'Switch to or create a git branch'
    if not git rev-parse --is-inside-work-tree >/dev/null 2>&1
        echo "Not a git repo."
        return 1
    end
    
    # Check if the branch already exists locally
    if git show-ref --verify --quiet refs/heads/$argv[1]
        git checkout $argv
    else
        # If it doesn't exist, create it
                git checkout -b $argv
        end
end
