# Copyright (C) 2026 Rootiest
# SPDX-License-Identifier: AGPL-3.0-or-later

# SYNOPSIS
#   copy <source> <dest>
#
# DESCRIPTION
#   Wrapper for cp that strips trailing slashes from source directories,
#   preventing unwanted nested copies when the destination already exists.
#
# ARGUMENTS
#   source  Source file or directory
#   dest    Destination path
#
# EXAMPLE
#   copy ./mydir/ ~/backup
function copy
    set count (count $argv)
    if test "$count" = 2; and test -d "$argv[1]"
        # 'string trim' is built straight into Fish and works everywhere
        set from (string trim --right --chars=/ $argv[1])
        set to (echo $argv[2])
        command cp -r $from $to
    else
        command cp $argv
    end
end
