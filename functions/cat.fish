# Copyright (C) 2026 Rootiest
# SPDX-License-Identifier: AGPL-3.0-or-later

function cat --wraps=bat --description 'alias cat=bat'
    bat --plain --no-pager $argv
end
