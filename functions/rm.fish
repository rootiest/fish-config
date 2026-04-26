# Copyright (C) 2026 Rootiest
# SPDX-License-Identifier: AGPL-3.0-or-later

function rm --description 'Ultimate rm: trash, list, empty, and secure-erase'
    # 1. No arguments: Show the Trash contents (Quick view)
    if not set -q argv[1]
        if type -q trash
            echo "🗑️ Current Trash Contents:"
            trash list
        else
            command rm
        end
        return
    end

    # 2. Flag: Empty the Trash (-e / --empty)
    # We check if the FIRST argument is -e or --empty
    if string match -rq -- '^-e$|^--empty$' -- $argv[1]
        if type -q trash
            # Check if there are arguments after -e (like --within 2weeks)
            if set -q argv[2]
                # Pass everything after the first argument to trash empty
                trash empty $argv[2..-1]
            else
                # Default behavior if no extra args provided
                echo "🧹 Emptying all trash..."
                trash empty --all
            end
        else
            echo "Error: 'trash' command not found."
        end
        return
    end

    # 3. Flag: Secure Delete (-S / --secure)
    if contains -- -S $argv; or contains -- --secure $argv
        set -l clean_args
        for arg in $argv
            if not string match -rq -- '^-S$|^--secure$|^-r$|^-R$|^--recursive$' -- "$arg"
                set -a clean_args $arg
            end
        end
        echo "🛡️ Permanent delete + SSD Zeroing..."
        command rm -rf $clean_args
        fstrim --all 2>/dev/null &
        return
    end

    # 4. Logic: Use 'trash' for simple paths OR recursive flags (-r, -R)
    # Bail to real rm if ANY other flags (like -f) are detected
    set -l is_safe_for_trash true
    for arg in $argv
        if string match -q -- "-*" $arg
            if not string match -rq -- '^-r$|^-R$|^--recursive$' -- "$arg"
                set is_safe_for_trash false
                break
            end
        end
    end

    if test "$is_safe_for_trash" = true
        set -l trash_paths
        for arg in $argv
            if not string match -rq -- '^-r$|^-R$|^--recursive$' -- "$arg"
                set -a trash_paths $arg
            end
        end

        if type -q trash; and set -q trash_paths[1]
            trash put $trash_paths
            # Refresh Dolphin view
            dbus-send --type=signal /OrgKdeKDirNotify org.kde.KDirNotify.FilesChanged stringArray:"trash:/" >/dev/null 2>&1 &
            return
        end
    end

    # 5. Fallback: Standard rm for everything else (including -rf)
    command rm $argv
end
