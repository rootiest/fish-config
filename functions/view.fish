# Copyright (C) 2026 Rootiest
# SPDX-License-Identifier: AGPL-3.0-or-later

function view --wraps='neovim -R' --wraps='nvim -R' --description 'alias view=nvim -R'
  nvim -R $argv
        
end
