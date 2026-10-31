# Copyright (C) 2026 Rootiest
# SPDX-License-Identifier: AGPL-3.0-or-later

# SYNOPSIS
#   __bashrun_execute
#
# DESCRIPTION
#   Bound to Enter. A command line Fish can parse, or one __bashrun_wanted
#   leaves to Fish, executes as usual (an incomplete block still gets a
#   newline). A Bash snippet is rewritten to bashrun '<snippet>' and then
#   executed, so the rewrite shows on screen and lands in history.
#
# EXAMPLE
#   bind enter __bashrun_execute
function __bashrun_execute
    if not commandline --paging-mode; and not commandline --search-mode
        commandline --is-valid
        set -l validity $status
        # "$(...)" keeps a multi-line buffer one string instead of one per line.
        set -l text "$(commandline)"
        if __bashrun_wanted $validity $text
            set -l code "$(string replace -a -- \\ \\\\ $text | string replace -a -- \' \\\')"
            commandline -r -- "bashrun '$code'"
        end
    end
    commandline -f execute
end
