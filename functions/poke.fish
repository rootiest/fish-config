# Copyright (C) 2026 Rootiest
# SPDX-License-Identifier: AGPL-3.0-or-later

# SYNOPSIS
#   poke <file> [file...]
#
# DESCRIPTION
#   Creates files using touch, automatically creating any missing parent
#   directories via _fish_mkdir_p with tree output.
#
# ARGUMENTS
#   file  One or more file paths to create
#
# RETURNS
#   0  Files created
#   1  No file argument provided
#
# EXAMPLE
#   poke ~/projects/new/src/main.fish
function poke --description 'touch with automatic parent directory creation'
    if test (count $argv) -eq 0
        echo (set_color red)"poke: no file specified"(set_color normal) >&2
        return 1
    end
    for _path in $argv
        set -l _dir (dirname $_path)
        _fish_mkdir_p --tree $_dir
        touch $_path
    end
end
