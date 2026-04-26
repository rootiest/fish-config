# Copyright (C) 2026 Rootiest
# SPDX-License-Identifier: AGPL-3.0-or-later

function du
    set cmd ""
    set args

    # Parse override flags and gather remaining args
    for arg in $argv
        switch $arg
            case --disk
                set cmd duf
            case --dir
                set cmd dust
            case --dua
                set cmd dua
            case '*'
                set args $args $arg
        end
    end

    # Autodetect if no override flag given
    if test -z "$cmd"
        if count $args
            set first_arg $args[1]
            if test -d "$first_arg" -o -f "$first_arg"
                set cmd dust
            else
                set cmd duf
            end
        else
            set cmd duf
        end
    end

    # Tool execution with graceful fallback
    switch $cmd
        case duf
            if type -q duf
                duf $args
            else
                echo "(duf not found — falling back to du)"
                command du -sh $args
            end
        case dust
            if type -q dust
                dust $args
            else
                echo "(dust not found — falling back to du)"
                command du -sh $args
            end
        case dua
            if type -q dua
                dua $args
            else
                echo "(dua not found — falling back to du)"
                command du -sh $args
            end
        case '*'
            # This shouldn't happen, but just in case
            command du -sh $args
    end
end
