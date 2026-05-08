# Copyright (C) 2026 Rootiest
# SPDX-License-Identifier: AGPL-3.0-or-later

# Run joplin CLI without Node deprecation warnings
function joplin --description 'Run Joplin CLI without Node deprecation warnings'
    set -l joplin_path (command -v joplin)
    if test -n "$joplin_path"
        NODE_OPTIONS="--no-deprecation" $joplin_path $argv
    else
        echo "Error: joplin binary not found in PATH" >&2
        return 1
    end
end
