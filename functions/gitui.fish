# Copyright (C) 2026 Rootiest
# SPDX-License-Identifier: AGPL-3.0-or-later

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
# EXAMPLE
#   gitui
function gitui --wraps='gitui' --description 'alias gitui=gitui -t mocha.ron'
    command gitui -t frappe.ron $argv

end
