# Copyright (C) 2026 Rootiest
# SPDX-License-Identifier: AGPL-3.0-or-later

# CATEGORY
#   02-navigation
#
# DEPENDENCIES
#   clone-in-kitty
#
# SYNOPSIS
#   clonet [args...]
#
# DESCRIPTION
#   Alias for clone-in-kitty --type=tab that clones a repository into a new
#   Kitty terminal tab. Only works inside the Kitty terminal.
#
# ARGUMENTS
#   args...  Arguments forwarded to clone-in-kitty (typically a repo URL)
#
# EXIT STATUS
#   0  Repository cloned
#   1  Not running inside Kitty terminal, or clone-in-kitty isn't available
#
# EXAMPLE
#   clonet https://github.com/user/repo.git
function clonet --wraps='clone-in-kitty --type=tab' --description 'alias clonet=clone-in-kitty --type=tab'
    if test "$TERM" != xterm-kitty
        echo "Error: The 'clonet' command requires Kitty terminal." >&2
        return 1
    end
    # $TERM only proves the terminal type -- clone-in-kitty is a function
    # Kitty's own shell integration injects, which doesn't happen over an
    # ssh session that merely inherits $TERM from the local Kitty.
    if not type -q clone-in-kitty
        echo "Error: 'clonet' detected Kitty but clone-in-kitty isn't available (shell integration not loaded)." >&2
        return 1
    end
    clone-in-kitty --type=tab $argv
end
