# Copyright (C) 2026 Rootiest
# SPDX-License-Identifier: AGPL-3.0-or-later

# SYNOPSIS
#   edit [args...]
#
# DESCRIPTION
#   Opens files in nvim, falling back to $EDITOR, nano, or vi if nvim is not
#   installed.
#
# ARGUMENTS
#   args...  Files and options forwarded to the editor
#
# EXAMPLE
#   edit ~/.config/fish/config.fish
function edit --wraps='nvim' --description 'alias edit=nvim'
    if type -q nvim
        nvim $argv
    else if set -q EDITOR
        $EDITOR $argv
    else if type -q nano
        nano $argv
    else
        vi $argv
    end
end
