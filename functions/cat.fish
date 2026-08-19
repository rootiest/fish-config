# Copyright (C) 2026 Rootiest
# SPDX-License-Identifier: AGPL-3.0-or-later

# CATEGORY
#   01-file-and-directory
#
# COMPONENT
#   aliases/filesystem
#
# SYNOPSIS
#   cat [args...]
#
# DESCRIPTION
#   Enhanced cat replacement. Wraps bat for files, giving syntax highlighting
#   and line numbers; passes directories to ls; falls back to raw cat for
#   ANSI-colored log files, and finally to /usr/bin/cat if bat is not
#   installed.
#
# ARGUMENTS
#   args...  Files or directories to display
#
# EXAMPLE
#   cat README.md
#   cat ~/projects/myapp
function cat --wraps='bat' --description 'Use bat for files, ls for directories, and raw cat for ANSI logs'
    # Opinionated guard (C1): fall back to bare command cat when disabled.
    if not __fish_config_op_enabled (status current-function)
        command cat $argv
        return $status
    end

    # If no arguments are provided, cat usually waits for stdin.
    # We'll maintain that behavior by skipping the directory check if $argv is empty.
    if set -q argv[1]
        if test -d $argv[1]
            # If it's a directory, run your custom ls function
            ls $argv
            return
        end

        # NEW: Check if the target file lives in your scrollback snapshot directory OR 
        # contains raw terminal ANSI color escape sequences.
        if test -f $argv[1]
            if string match -q "$SCROLLBACK_HISTORY_DIR/*" $argv[1]
                or string match -qr -- '\e\[[0-9;]*m' (head -n 5 $argv[1] 2>/dev/null)
                command cat $argv
                return
            end
        end
    end

    # Fallback to bat or standard cat
    if type -q bat
        bat --plain --no-pager $argv
    else
        command cat $argv
    end
end
