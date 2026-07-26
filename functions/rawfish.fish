# Copyright (C) 2026 Rootiest
# SPDX-License-Identifier: AGPL-3.0-or-later

# CATEGORY
#   03-editors-and-viewers
#
# SYNOPSIS
#   rawfish [args...]
#
# DESCRIPTION
#   Launches a Fish shell with NO_TMUX=1 set, bypassing any tmux
#   auto-attach or session management hooks.
#
# ARGUMENTS
#   args...  Arguments forwarded to fish
#
# EXAMPLE
#   rawfish
function rawfish --wraps='env NO_TMUX=1 fish' --description 'alias rawfish=env NO_TMUX=1 fish'
  env NO_TMUX=1 fish $argv
        
end
