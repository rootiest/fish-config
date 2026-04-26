# Copyright (C) 2026 Rootiest
# SPDX-License-Identifier: AGPL-3.0-or-later

function tab --wraps='konsole --new-tab --workdir "$cdto"' --description 'alias tab=konsole --new-tab --workdir "$cdto"'
  konsole --new-tab --workdir "$cdto" $argv
        
end
