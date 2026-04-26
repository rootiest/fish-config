# Copyright (C) 2026 Rootiest
# SPDX-License-Identifier: AGPL-3.0-or-later

function detach
    set -l show_help 0
    set -l args

    for arg in $argv
        switch $arg
            case -h --help
                set show_help 1
            case --version
                echo "detach 1.0.0"
                return
            case '-*' '--*'
                echo "❌ Unknown option: $arg"
                echo "Run 'detach --help' for usage."
                return 1
            case '*'
                set args $args $arg
        end
    end

    if test $show_help -eq 1
        echo "Usage: detach [command...]"
        echo "Runs a command in the background, fully detached from the terminal."
        echo
        echo "Options:"
        echo "  -h, --help        Show this help message"
        echo "  --version         Show version information"
        echo
        echo "Example:"
        echo "  detach firefox"
        echo "  detach rsync -a ./data remote:/backup/"
        return
    end

    if test (count $args) -eq 0
        echo "❌ No command provided."
        echo "Run 'detach --help' for usage."
        return 1
    end

    nohup $args >/dev/null 2>&1 &
end
