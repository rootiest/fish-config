# Copyright (C) 2026 Rootiest
# SPDX-License-Identifier: AGPL-3.0-or-later

function nlazyup --wraps='nvim --headless "+Lazy! sync" +qa' --description 'alias nlazyup=nvim --headless "+Lazy! sync" +qa'
  nvim --headless "+Lazy! sync" +qa $argv
        
end
