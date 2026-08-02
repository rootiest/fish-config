# Copyright (C) 2026 Rootiest
# SPDX-License-Identifier: AGPL-3.0-or-later

# SYNOPSIS
#   __jobrunner_sessions
#
# DESCRIPTION
#   Parses `screen -ls` into machine-readable rows, one per active session:
#   name, PID, state, and start time separated by tabs. Shared by jobrunner
#   and its completions so both agree on what a session is named. Prints
#   nothing when no sessions exist.
#
# EXIT STATUS
#   0  Parsed successfully (including the zero-session case)
#   1  screen is not installed
#
# RETURNS
#   One line per session: <name>\t<pid>\t<state>\t<started>
#
# EXAMPLE
#   __jobrunner_sessions
#   __jobrunner_sessions | string replace -r '\t.*$' ''
function __jobrunner_sessions --description 'List active screen sessions as name/pid/state/started rows'
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
end
