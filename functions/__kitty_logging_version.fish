# Copyright (C) 2026 Rootiest
# SPDX-License-Identifier: AGPL-3.0-or-later

# SYNOPSIS
#   __kitty_logging_version <file>
#
# DESCRIPTION
#   Prints the integer value of the "fish-config-watcher-version:" marker in the
#   given watcher file, or 0 if the file is missing or has no marker.
#
# ARGUMENTS
#   file  Path to a watcher script
#
# EXIT STATUS
#   0  Always
#
# RETURNS
#   The watcher version as an integer (0 if absent), printed to stdout
#
# EXAMPLE
#   __kitty_logging_version ~/.config/kitty/fish-config-watcher.py
function __kitty_logging_version --argument-names file --description 'Read the watcher version marker (0 if absent)'
    if not test -f "$file"
        echo 0
        return 0
    end
    set -l v (string match -gr 'fish-config-watcher-version: *([0-9]+)' <$file)
    if set -q v[1]; and test -n "$v[1]"
        echo $v[1]
    else
        echo 0
    end
end
