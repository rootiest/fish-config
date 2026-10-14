# Copyright (C) 2026 Rootiest
# SPDX-License-Identifier: AGPL-3.0-or-later

# SYNOPSIS
#   __session_env_desktop_build SOURCE MARKER VAR...
#
# DESCRIPTION
#   Prints the user-level copy of the desktop entry SOURCE that
#   __session_env_desktop writes: three marker lines (MARKER, the
#   variables, the source path) followed by SOURCE with "env -u VAR ..."
#   inserted after every "Exec=". Keys other than Exec (including
#   TryExec) and all comments pass through unchanged. Also used to detect
#   a managed copy that has gone stale.
#
# EXIT STATUS
#   0  Always
#
# RETURNS
#   The desktop entry text, on stdout
#
# EXAMPLE
#   __session_env_desktop_build /usr/share/applications/x.desktop "# Managed" DO_NOT_TRACK
function __session_env_desktop_build --description 'Render a .desktop override with env -u prefixes'
    set -l src $argv[1]
    set -l marker $argv[2]
    set -l vars $argv[3..]
    set -l prefix env
    for v in $vars
        set prefix "$prefix -u $v"
    end
    echo $marker
    echo "# session-env-unset: $vars"
    echo "# session-env-source: $src"
    # string split, not read: read would trim whitespace and eat backslashes.
    for line in (string split \n -- (string collect <$src))
        if string match -q 'Exec=*' -- $line
            echo "Exec=$prefix "(string replace 'Exec=' '' -- $line)
        else
            printf '%s\n' $line
        end
    end
end
