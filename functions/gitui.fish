# Copyright (C) 2026 Rootiest
# SPDX-License-Identifier: AGPL-3.0-or-later

# CATEGORY
#   04-git-and-version-control
#
# DEPENDENCIES
#   gitui
#
# SYNOPSIS
#   gitui [args...]
#
# DESCRIPTION
#   Launches gitui with the Catppuccin Frappe theme (frappe.ron), passing any
#   additional arguments through to the gitui command.
#
# ARGUMENTS
#   args...  Arguments forwarded to the gitui command
#
# EXIT STATUS
#   1  gitui is not installed
#   *  Exit status of gitui otherwise
#
# EXAMPLE
#   gitui
function gitui --wraps='gitui' --description 'alias gitui=gitui -t mocha.ron'
    if not type -q -f gitui
        echo (set_color red)"Error: gitui is not installed."(set_color normal) >&2
        return 1
    end

    command gitui -t frappe.ron $argv
end
