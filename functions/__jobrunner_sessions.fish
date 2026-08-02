# Copyright (C) 2026 Rootiest
# SPDX-License-Identifier: AGPL-3.0-or-later

# SYNOPSIS
#   __jobrunner_sessions [<tool>]
#
# DESCRIPTION
#   Parses `tmux list-sessions` or `screen -ls` into machine-readable rows,
#   one per active session: name, PID, state, and start time separated by tabs.
#   Shared by jobrunner and its completions so both agree on what a session is
#   named. Prints nothing when no sessions exist.
#
# EXIT STATUS
#   0  Parsed successfully (including the zero-session case)
#   1  tool (tmux or screen) is not installed
#
# RETURNS
#   One line per session: <name>\t<pid>\t<state>\t<started>
#
# EXAMPLE
#   __jobrunner_sessions
#   __jobrunner_sessions tmux | string replace -r '\t.*$' ''
function __jobrunner_sessions --description 'List active jobrunner sessions as name/pid/state/started rows'
    set -l tool $argv[1]
    if test -z "$tool"
        if command -q tmux
            set tool tmux
        else if command -q screen
            set tool screen
        else
            return 1
        end
    end

    if test "$tool" = tmux
        command -q tmux; or return 1
        set -l tab (printf '\t')
        for line in (command tmux list-sessions -F "#{session_name}$tab#{pid}$tab#{?session_attached,Attached,Detached}$tab#{t:session_created}" 2>/dev/null)
            # tmux output is natively tab-separated.
            printf '%s\n' $line
        end
    else if test "$tool" = screen
        command -q screen; or return 1
        # screen -ls exits 1 when nothing is running; the parse handles that.
        for line in (command screen -ls 2>/dev/null)
            # Session rows are tab-indented and start with "<pid>.<name>".
            set -l m (string match -r '^\s+(\d+)\.([^\t]+)\t(.*)$' -- $line)
            or continue

            # Trailing fields are parenthesized: "(<date>)\t(<state>)", and some
            # screen builds omit the date, so read the state off the end.
            set -l fields (string split \t -- $m[4])
            set -l state (string trim -c '()' -- $fields[-1])
            set -l started ""
            if test (count $fields) -gt 1
                set started (string trim -c '()' -- $fields[1])
            end

            printf '%s\t%s\t%s\t%s\n' $m[3] $m[2] $state $started
        end
    else
        return 1
    end
end
