# Copyright (C) 2026 Rootiest
# SPDX-License-Identifier: AGPL-3.0-or-later

# prettyping with default nolegend
function ping --description 'prettyping with default nolegend'
    if command -q prettyping
        # Check if the user specifically asked for the legend
        if contains -- --legend $argv
            command prettyping $argv
        else
            command prettyping --nolegend $argv
        end
    else
        # Fallback to standard ping if prettyping isn't installed
        command ping $argv
    end
end
