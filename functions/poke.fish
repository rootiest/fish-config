# Copyright (C) 2026 Rootiest
# SPDX-License-Identifier: AGPL-3.0-or-later

function poke --description 'touch with automatic parent directory creation'
    if test (count $argv) -eq 0
        echo (set_color red)"poke: no file specified"(set_color normal) >&2
        return 1
    end
    for _path in $argv
        set -l _dir (dirname $_path)
        if not test -d $_dir
            mkdir -p $_dir
            and echo (set_color --bold cyan)"Created: "(set_color cyan)"$_dir"(set_color normal)
        end
        touch $_path
    end
end
