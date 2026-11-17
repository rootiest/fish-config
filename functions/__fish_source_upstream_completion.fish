# Copyright (C) 2026 Rootiest
# SPDX-License-Identifier: AGPL-3.0-or-later

# SYNOPSIS
#   __fish_source_upstream_completion COMMAND CALLER
#
# DESCRIPTION
#   Loads the completions fish itself ships for COMMAND. A file named
#   completions/COMMAND.fish here hides fish's own copy, since fish autoloads
#   only the first match on $fish_complete_path. A completion file that only
#   adds options to a shadowed command calls this first, then adds its own.
#
#   Searches $fish_complete_path for COMMAND.fish, skipping CALLER (the
#   calling file, as `status filename` gives it), then falls back to the copy
#   embedded in the fish binary (fish 4 and later).
#
# EXIT STATUS
#   0  Upstream completions were found and sourced
#   1  No upstream completions exist for COMMAND
#
# EXAMPLE
#   __fish_source_upstream_completion du (status filename)
function __fish_source_upstream_completion --argument-names cmd caller
    set -l self (path resolve -- $caller)
    for dir in $fish_complete_path
        set -l file $dir/$cmd.fish
        test -f $file; or continue
        test (path resolve -- $file) = "$self"; and continue
        source $file
        return 0
    end

    set -l embedded (status get-file completions/$cmd.fish 2>/dev/null)
    or return 1
    string join \n -- $embedded | source
end
