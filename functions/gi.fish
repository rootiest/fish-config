# Generate .gitignore files using the gitignore.io API
function gi --description 'Generate .gitignore files using the gitignore.io API'
    # Define the flags
    argparse h/help d/description l/list -- $argv
    or return 1

    # Help output
    if set -q _flag_help
        echo "Usage: gi [TARGETS...] [FLAGS]"
        echo ""
        echo "Arguments:"
        echo "  TARGETS       Comma-separated list of languages or tools (e.g., c++,neovim,archlinux)"
        echo ""
        echo "Flags:"
        echo "  -h, --help        Show this help message"
        echo "  -d, --description Show the Fish function description"
        echo "  -l, --list        List all supported targets from the API"
        echo ""
        echo "Examples:"
        echo "  gi c++                  # Print C++ gitignore to stdout"
        echo "  gi python,venv > .gitignore # Create a file for Python and venv"
        echo "  gi -l | grep -i linux   # Search for specific OS support"
        return 0
    end

    # Print the function description
    if set -q _flag_description
        functions -D gi
        return 0
    end

    # Handle the list flag
    if set -q _flag_list
        curl -sL https://www.toptal.com/developers/gitignore/api/list
        return 0
    end

    # Error if no arguments provided
    if not set -q argv[1]
        echo "Error: No targets provided. Use 'gi --help' for usage." >&2
        return 1
    end

    # Execute the API call
    # We replace any spaces with commas just in case you pass them as separate args
    set -l targets (string join "," $argv)

    echo "## Generating .gitignore for: $targets"
    curl -f -sL "https://www.toptal.com/developers/gitignore/api/$targets"

    if test $status -ne 0
        echo "Error: Failed to fetch gitignore. Are the targets spelled correctly?" >&2
        return 1
    end
end
