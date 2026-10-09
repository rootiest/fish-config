# Copyright (C) 2026 Rootiest
# SPDX-License-Identifier: AGPL-3.0-or-later

# CATEGORY
#   14-miscellaneous
#
# DEPENDENCIES
#   docker
#
# CLASSIFICATION
#   network
#
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
# EXIT STATUS
#   0  Services updated and running
#   1  Directory not found, no docker-compose.yml present, or docker missing
#   2  docker compose pull/up failed
#
# EXAMPLE
#   dockup ~/myapp
function dockup --description 'Pull and restart docker compose containers'
    # Define colors
    set -l clr_error (__fish_color red)
    set -l clr_info (__fish_color -b blue white)
    set -l clr_success (__fish_color green)
    set -l clr_off (__fish_color normal)

    # Handle help flags
    if contains -- -h $argv; or contains -- --help $argv
        __fish_palette
        echo "$c_head""Usage:$c_reset $c_cmd""dockup$c_reset $c_arg""[DIRECTORY]$c_reset"
        echo ""
        echo "$c_head""Options:$c_reset"
        echo "  $c_flag-h$c_reset, $c_flag--help$c_reset    Show this help message"
        echo ""
        echo "$c_head""Arguments:$c_reset"
        echo "  $c_arg""DIRECTORY$c_reset     Optional path to the compose project (defaults to current dir)"
        return 0
    end

    if not type -q docker
        echo $clr_error"Error: docker is not installed."$clr_off >&2
        return 1
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
    echo $clr_info" UPDATING "$clr_off" Containers in "(__fish_color -o)(pwd)$clr_off"..."

    set -l rc 0
    if docker compose pull && docker compose up -d --remove-orphans
        echo $clr_success"✔ Upgrade complete!"$clr_off
        docker image prune -f
    else
        echo $clr_error"✘ Upgrade failed."$clr_off >&2
        set rc 2
    end

    # Cleanup directory state
    if count $argv >/dev/null
        popd >/dev/null
    end

    return $rc
end
