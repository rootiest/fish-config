# Copyright (C) 2026 Rootiest
# SPDX-License-Identifier: AGPL-3.0-or-later

# SYNOPSIS
#   dockup [-h] [directory]
#
# DESCRIPTION
#   Pulls the latest Docker images and restarts all services in a Docker Compose
#   project, then prunes dangling images. Accepts an optional target directory.
#
# ARGUMENTS
#   -h, --help   Show help message
#   directory    Path to the compose project (defaults to current directory)
#
# RETURNS
#   0  Services updated and running
#   1  Directory not found or no docker-compose.yml present
#
# EXAMPLE
#   dockup ~/myapp
function dockup --description 'Pull and restart docker compose containers'
    # Define colors
    set -l clr_error (set_color red)
    set -l clr_info (set_color -b blue white)
    set -l clr_success (set_color green)
    set -l clr_off (set_color normal)

    # Handle help flags
    if contains -- -h $argv; or contains -- --help $argv
        echo (set_color -o yellow)"Usage:"$clr_off" dockup [DIRECTORY]"
        echo ""
        echo (set_color -u)"Options:"$clr_off
        echo "  -h, --help    Show this help message"
        echo ""
        echo (set_color -u)"Arguments:"$clr_off
        echo "  DIRECTORY     Optional path to the compose project (defaults to current dir)"
        return 0
    end

    # Handle directory navigation
    if count $argv >/dev/null
        set -l target_dir $argv[1]
        if test -d $target_dir
            pushd $target_dir >/dev/null
        else
            echo $clr_error"Error: Directory '$target_dir' not found."$clr_off
            return 1
        end
    end

    # Check for compose file
    if not test -f docker-compose.yml -o -f docker-compose.yaml
        echo $clr_error"Error: No docker-compose.yml found in "(pwd)$clr_off
        if count $argv >/dev/null
            popd >/dev/null
        end
        return 1
    end

    # Execution
    echo $clr_info" UPDATING "$clr_off" Containers in "(set_color -o)(pwd)$clr_off"..."

    if docker compose pull && docker compose up -d --remove-orphans
        echo $clr_success"✔ Upgrade complete!"$clr_off
        docker image prune -f
    else
        echo $clr_error"✘ Upgrade failed."$clr_off
    end

    # Cleanup directory state
    if count $argv >/dev/null
        popd >/dev/null
    end
end
