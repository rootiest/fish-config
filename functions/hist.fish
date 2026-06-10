# Copyright (C) 2026 Rootiest
# SPDX-License-Identifier: AGPL-3.0-or-later

# SYNOPSIS
#   hist
#
# DESCRIPTION
#   Searches fish history interactively using fzf, inserts the selected command
#   into the command line, and copies it to the clipboard via wl-copy.
#
# EXAMPLE
#   hist
function hist --description 'Search fish history and put it in the prompt'
    # Opinionated guard (C4): integrations disabled
    if not __fish_config_op_enabled __fish_config_op_integrations
        set -l c_err (set_color red)
        set -l c_reset (set_color normal)
        echo "$c_err"'hist: disabled by __fish_config_op_integrations'"$c_reset" >&2
        return 1
    end

    set -l selected (history | fzf --reverse --height 40% --with-nth 3..)

    if test -n "$selected"
        # Strip the timestamp for the final output
        set -l command (echo $selected | string replace -r '^\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2} ' '')
        
        echo $command | wl-copy 2>/dev/null
        commandline -r $command
    end
end
