# Copyright (C) 2026 Rootiest
# SPDX-License-Identifier: AGPL-3.0-or-later

# CATEGORY
#   02-navigation
#
# SYNOPSIS
#   clone [args...]
#
# DESCRIPTION
#   Alias for clone-in-kitty that clones a repository into a new Kitty terminal
#   window. Only works inside the Kitty terminal.
#
# ARGUMENTS
#   args...  Arguments forwarded to clone-in-kitty (typically a repo URL)
#
# EXIT STATUS
#   0  Repository cloned
#   1  Not running inside Kitty terminal
#
# EXAMPLE
#   clone https://github.com/user/repo.git
function clone --wraps='clone-in-kitty' --description 'alias clone=clone-in-kitty'
    if test "$TERM" != xterm-kitty
        echo "Error: The 'clone' command requires Kitty terminal." >&2
        return 1
    end
    clone-in-kitty $argv
end
