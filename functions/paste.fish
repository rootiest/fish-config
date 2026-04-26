# Copyright (C) 2026 Rootiest
# SPDX-License-Identifier: AGPL-3.0-or-later

function paste --description 'Paste from clipboard'
    if type -q wl-paste
        wl-paste $argv
    else if type -q xclip
        xclip -selection clipboard -o $argv
    else
        echo "Error: Neither wl-paste nor xclip found." >&2
        return 1
    end
end
