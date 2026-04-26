# Copyright (C) 2026 Rootiest
# SPDX-License-Identifier: AGPL-3.0-or-later

function edit --wraps=nvim --description 'alias edit=nvim'
    nvim $argv
end
