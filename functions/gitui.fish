# Copyright (C) 2026 Rootiest
# SPDX-License-Identifier: AGPL-3.0-or-later

# alias gitui=gitui -t mocha.ron
function gitui --wraps='gitui' --description 'alias gitui=gitui -t mocha.ron'
    command gitui -t frappe.ron $argv

end
