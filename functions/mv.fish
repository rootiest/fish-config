# Copyright (C) 2026 Rootiest
# SPDX-License-Identifier: AGPL-3.0-or-later

# CATEGORY
#   01-file-and-directory
#
# SYNOPSIS
#   mv [args...]
#
# DESCRIPTION
#   Wraps mv to automatically collapse nested directories of the same name.
#   When extracting archives results in redundant structures (e.g.,
#   themes/themes/), calling `mv themes/themes themes` will gracefully
#   move the inner contents up one level and remove the empty outer shell.
#
#   Opinionated component (C1): when disabled via __fish_config_op_aliases,
#   behaves exactly like bare command mv.
#
# ARGUMENTS
#   args...  Arguments forwarded to standard mv
#
# EXIT STATUS
#   0   Operation succeeded
#   >0  Standard mv failure, or failed to collapse directory
#
# EXAMPLE
#   mv ~/.config/btop/themes/themes ~/.config/btop/themes
function mv --wraps='mv' --description 'Move files with auto-collapse for nested directories'
    # Opinionated guard (C1): fall back to bare command mv when disabled.
    if not __fish_config_op_enabled __fish_config_op_aliases
        command mv $argv
        return $status
    end

    # 1. Parse arguments to separate flags from paths
    set -l paths
    set -l flags
    for arg in $argv
        if string match -q -- "-*" "$arg"
            set -a flags "$arg"
        else
            set -a paths "$arg"
        end
    end

    # 2. Condition: exactly two path arguments provided
    if test (count $paths) -eq 2
        set -l src $paths[1]
        set -l dst $paths[2]

        # Condition: both arguments must be directories
        if test -d "$src"; and test -d "$dst"
            # Resolve to absolute paths to prevent relative path mismatches
            set -l real_src (realpath "$src" 2>/dev/null)
            set -l real_dst (realpath "$dst" 2>/dev/null)

            if test -n "$real_src"; and test -n "$real_dst"
                set -l src_dir (dirname "$real_src")
                set -l src_base (basename "$real_src")
                set -l dst_base (basename "$real_dst")

                # 3. Intercept: child is directly inside parent, and names match perfectly
                if test "$src_dir" = "$real_dst"; and test "$src_base" = "$dst_base"
                    echo "📦 Auto-collapsing nested directory: $src_base"

                    # Gather all items safely (includes hidden files, excludes . and ..)
                    set -l items (find "$real_src" -mindepth 1 -maxdepth 1)
                    set -l mv_status 0

                    if test -n "$items"
                        for item in $items
                            command mv $flags "$item" "$real_dst/"
                            if test $status -ne 0
                                set mv_status 1
                            end
                        end
                    end

                    # Clean up the inner directory if the move was entirely successful
                    if test $mv_status -eq 0
                        command rmdir "$real_src" 2>/dev/null
                    else
                        set_color yellow
                        echo "⚠️ Some items could not be moved. Nested directory preserved." >&2
                        set_color normal
                    end

                    return $mv_status
                end
            end
        end
    end

    # 4. Fallback: Standard mv behavior for everything else
    command mv $argv
end
