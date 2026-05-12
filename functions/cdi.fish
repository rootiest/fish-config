# Copyright (C) 2026 Rootiest
# SPDX-License-Identifier: AGPL-3.0-or-later

function cdi --wraps zi --description 'Interactively jump to a directory using zoxide (alias for zi)'
    zi $argv
end
