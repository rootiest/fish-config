# Copyright (C) 2026 Rootiest
# SPDX-License-Identifier: AGPL-3.0-or-later

# SYNOPSIS
#   cdi [query]
#
# DESCRIPTION
#   Alias for zi — opens zoxide's interactive directory picker for jumping to
#   frequently-visited directories using fzf.
#
# ARGUMENTS
#   query  Optional search term to pre-filter the directory list
#
# EXAMPLE
#   cdi myproject
function cdi --wraps zi --description 'Interactively jump to a directory using zoxide (alias for zi)'
    zi $argv
end
