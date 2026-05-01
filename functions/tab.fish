# Copyright (C) 2026 Rootiest
# SPDX-License-Identifier: AGPL-3.0-or-later

# Spawn a new tab in the current terminal
function tab --description 'Spawn a new tab in the current terminal'
    set -l dir "$cdto"
    if test -z "$dir"
        set dir "$PWD"
    end

    if test "$TERM" = xterm-kitty
        kitty @ launch --type=tab --cwd="$dir" $argv
    else if test "$TERM_PROGRAM" = WezTerm
        wezterm cli spawn --cwd "$dir" $argv
    else if set -q KONSOLE_VERSION
        konsole --new-tab --workdir "$dir" $argv
    else
        echo "Error: No supported terminal found. Try Kitty, WezTerm, or Konsole." >&2
        return 1
    end
end
