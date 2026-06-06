# Copyright (C) 2026 Rootiest
# SPDX-License-Identifier: AGPL-3.0-or-later

# SYNOPSIS
#   rm [-e [options] | -S | args...]
#
# DESCRIPTION
#   Enhanced rm that routes deletions through trash when safe. With no
#   arguments, lists current trash contents. -e/--empty empties the trash
#   (with optional trash-empty sub-arguments). -S/--secure permanently
#   deletes via rm -rf and triggers fstrim. Plain paths and -r/-R are sent
#   to trash put; any other flags fall back to system rm.
#
# ARGUMENTS
#   (none)              List current trash contents
#   -e, --empty [opts]  Empty the trash; opts forwarded to trash empty
#   -S, --secure        Permanently delete targets and run fstrim
#   -r, -R, --recursive Forwarded to trash put alongside path arguments
#   args...             Files or paths to trash or remove
#
# RETURNS
#   0  Operation succeeded
#   1  trash put failed or file not found
#
# EXAMPLE
#   rm file.txt
#   rm -e
#   rm -S sensitive_key.pem
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
            set -l trash_output (trash put $trash_paths 2>&1)
            set -l exit_status $status

            if test $exit_status -ne 0
                # 1. Extract the core message (e.g., "No such file or directory")
                set -l raw_msg (string replace -r '.*Message: (.+?) \(os error.*' '$1' -- "$trash_output")

                # 2. Find which paths are actually missing
                set -l culprits
                for p in $trash_paths
                    if not test -e "$p"
                        set -a culprits "$p"
                    end
                end

                # 3. Display Logic
                set_color red --bold
                echo -n "error: "
                set_color normal
                echo $raw_msg

                if set -q culprits[1]
                    # If we found missing files, show the user's source paths
                    for c in $culprits
                        set_color blue
                        echo -n "  ↳ Source: "
                        set_color normal
                        echo $c
                    end
                else
                    # 1. Strip ANSI escape codes (color) so regex works correctly
                    # 2. Remove the 'error: ' prefix
                    # 3. Unescape quotes and trim whitespace
                    set -l clean_detail (string replace -ra '\e\[[^m]*m' '' -- "$trash_output" \
                                    | string replace -r '^error: ' '' \
                                    | string unescape \
                                    | string trim)

                    set_color yellow
                    echo -n "  ↳ Technical detail: "
                    set_color normal
                    echo $clean_detail
                end
            end

            dbus-send --type=signal /OrgKdeKDirNotify org.kde.KDirNotify.FilesChanged stringArray:"trash:/" >/dev/null 2>&1 &
            return $exit_status
        end
    end

    # 5. Fallback: Standard rm for everything else (including -rf)
    command rm $argv
end
