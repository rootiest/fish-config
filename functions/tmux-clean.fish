# Copyright (C) 2026 Rootiest
# SPDX-License-Identifier: AGPL-3.0-or-later

# CATEGORY
#   14-miscellaneous
#
# SYNOPSIS
#   tmux-clean
#
# DESCRIPTION
#   Kills all detached (unattached) tmux sessions, leaving any currently
#   attached sessions running.
#
# EXAMPLE
#   tmux-clean
function tmux-clean --description 'Kill all tmux sessions except the current one'
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
