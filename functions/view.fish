# Copyright (C) 2026 Rootiest
# SPDX-License-Identifier: AGPL-3.0-or-later

# SYNOPSIS
#   view [args...]
#
# DESCRIPTION
#   Opens files in nvim read-only mode (-R). Falls back to less if nvim
#   is not installed.
#
# ARGUMENTS
#   args...  Files or options forwarded to nvim -R or less
#
# EXAMPLE
#   view /etc/fstab
function view --wraps='nvim -R' --description 'alias view=nvim -R'
    if type -q nvim
        nvim -R $argv
    else
        less $argv
    end
        
end
