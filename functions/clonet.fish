# Copyright (C) 2026 Rootiest
# SPDX-License-Identifier: AGPL-3.0-or-later

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
# RETURNS
#   0  Repository cloned
#   1  Not running inside Kitty terminal
#
# EXAMPLE
#   clonet https://github.com/user/repo.git
function clonet --wraps='clone-in-kitty --type=tab' --description 'alias clonet=clone-in-kitty --type=tab'
    if test "$TERM" != xterm-kitty
        echo "Error: The 'clonet' command requires Kitty terminal." >&2
        return 1
    end
    clone-in-kitty --type=tab $argv
end
