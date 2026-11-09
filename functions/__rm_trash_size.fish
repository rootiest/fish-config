# Copyright (C) 2026 Rootiest
# SPDX-License-Identifier: AGPL-3.0-or-later

# SYNOPSIS
#   __rm_trash_size [MOUNT_POINT...]
#
# DESCRIPTION
#   Prints the size summary rm shows after listing the trash: a blank line,
#   then the total with its files/ and info/ breakdown. Measures the same
#   directories trash list reads, as the FreeDesktop Trash specification
#   defines them: $XDG_DATA_HOME/Trash (default ~/.local/share/Trash), plus
#   $top/.Trash/$uid (only when $top/.Trash is sticky and not a symlink) and
#   $top/.Trash-$uid on each mounted volume. Prints nothing when none exist.
#
# ARGUMENTS
#   MOUNT_POINT...  Volumes to scan instead of those in /proc/self/mounts
#
# EXIT STATUS
#   0  always
#
# RETURNS
#   The size summary on stdout, or nothing when no trash directory exists.
#
# EXAMPLE
#   __rm_trash_size
function __rm_trash_size --description 'Print the total size of the user trash'
    set -l data_home $XDG_DATA_HOME
    test -n "$data_home"; or set data_home $HOME/.local/share

    set -l roots
    test -d "$data_home/Trash"; and set -a roots "$data_home/Trash"

    set -l mounts $argv
    if not set -q mounts[1]; and test -r /proc/self/mounts
        set mounts (string split -f2 ' ' </proc/self/mounts)
    end

    set -l uid (command id -u)
    for mount in $mounts
        # The mount table writes spaces and the like as octal escapes.
        set -l top (printf %b $mount)
        set -l shared "$top/.Trash"
        if test -k "$shared"; and not test -L "$shared"; and test -d "$shared/$uid"
            set -a roots "$shared/$uid"
        end
        test -d "$top/.Trash-$uid"; and set -a roots "$top/.Trash-$uid"
    end

    set -q roots[1]; or return 0

    # -c appends a grand total as the last line, whatever the root count.
    set -l total (string split -f1 \t (command du -shc $roots 2>/dev/null)[-1])
    set -l files (string split -f1 \t (command du -shc $roots/files 2>/dev/null)[-1])
    set -l info (string split -f1 \t (command du -shc $roots/info 2>/dev/null)[-1])

    __fish_palette
    echo
    echo "$c_head""Trash Size:$c_reset $c_hi$total$c_reset $c_dim(files: $files, info: $info)$c_reset"
    return 0
end
