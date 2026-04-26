# Copyright (C) 2026 Rootiest
# SPDX-License-Identifier: AGPL-3.0-or-later

function cb --description 'Copy to clipboard'
    if type -q wl-copy
        if set -q argv[1]
            echo $argv | wl-copy
        else
            wl-copy
        end
    else if type -q xclip
        if set -q argv[1]
            echo $argv | xclip -selection clipboard
        else
            xclip -selection clipboard
        end
    else
        echo "Error: No clipboard provider found." >&2
        return 1
    end
end
