# Copyright (C) 2026 Rootiest
# SPDX-License-Identifier: AGPL-3.0-or-later

# CATEGORY
#   14-miscellaneous
#
# DEPENDENCIES
#   tmux
#
# SYNOPSIS
#   tmux-clean
#
# DESCRIPTION
#   Kills all detached (unattached) tmux sessions, leaving any currently
#   attached sessions running.
#
# EXIT STATUS
#   0  Detached sessions killed, or none found
#   1  tmux is not installed
#   2  Unexpected argument (takes none)
#
# EXAMPLE
#   tmux-clean
function tmux-clean --description 'Kill all tmux sessions except the current one'
    __fish_help_header (status current-function) $argv; and return 0
    __fish_no_args (status current-function) $argv; or return

    if not type -q tmux
        __fish_palette
        echo "$c_err"'tmux-clean: tmux is not installed'"$c_reset" >&2
        return 1
    end

    # Get a list of all session names that are NOT currently attached
    set sessions (tmux list-sessions -F '#{session_name} #{session_attached}' | string match -rv ' 1$' | string split -f1 ' ')

    if test -n "$sessions"
        for session in $sessions
            echo "Stopping session: $session"
            tmux kill-session -t "$session"
        end
        echo "Clean-up complete."
    else
        echo "No detached sessions to clean."
    end
end
