# Copyright (C) 2026 Rootiest
# SPDX-License-Identifier: AGPL-3.0-or-later

function clonet --wraps='clone-in-kitty --type=tab' --description 'alias clonet=clone-in-kitty --type=tab'
  clone-in-kitty --type=tab $argv
        
end
