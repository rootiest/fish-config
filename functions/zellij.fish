# Copyright (C) 2026 Rootiest
# SPDX-License-Identifier: AGPL-3.0-or-later

# SYNOPSIS
#   zellij [args...]
#
# DESCRIPTION
#   Launches zellij with the Catppuccin Mocha theme applied via
#   --theme catppuccin-mocha.
#
# ARGUMENTS
#   args...  Arguments forwarded to zellij
#
# EXAMPLE
#   zellij
function zellij --wraps='zellij' --description 'alias zellij=zellij options --theme catppuccin-mocha'
 command zellij options --theme catppuccin-mocha $argv
        
end
