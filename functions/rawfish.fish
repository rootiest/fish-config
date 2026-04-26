# Copyright (C) 2026 Rootiest
# SPDX-License-Identifier: AGPL-3.0-or-later

function rawfish --wraps='env NO_TMUX=1 fish' --description 'alias rawfish=env NO_TMUX=1 fish'
  env NO_TMUX=1 fish $argv
        
end
