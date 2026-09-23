# Copyright (C) 2026 Rootiest
# SPDX-License-Identifier: AGPL-3.0-or-later

# CATEGORY
#   02-navigation
#
# DEPENDENCIES
#   clone-in-kitty
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
#   1  Not running inside Kitty terminal, or clone-in-kitty isn't available
#
# EXAMPLE
#   clone https://github.com/user/repo.git
function clone --wraps='clone-in-kitty' --description 'alias clone=clone-in-kitty'
    if test "$TERM" != xterm-kitty
        echo "Error: The 'clone' command requires Kitty terminal." >&2
        return 1
    end
    # $TERM only proves the terminal type -- clone-in-kitty is a function
    # Kitty's own shell integration injects, which doesn't happen over an
    # ssh session that merely inherits $TERM from the local Kitty.
    if not type -q clone-in-kitty
        echo "Error: 'clone' detected Kitty but clone-in-kitty isn't available (shell integration not loaded)." >&2
        return 1
    end
    clone-in-kitty $argv
end
