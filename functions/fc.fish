# Copyright (C) 2026 Rootiest
# SPDX-License-Identifier: AGPL-3.0-or-later

# CATEGORY
#   03-editors-and-viewers
#
# SYNOPSIS
#   fc [command_prefix]
#
# DESCRIPTION
#   Edits the last shell command -- or the most recent one matching a
#   prefix -- in $EDITOR, then executes the result. Bash-style fc
#   behaviour. Falls back to vi when $EDITOR is unset, and aborts without
#   executing if the buffer is left empty.
#
# ARGUMENTS
#   command_prefix   Search history for the newest command matching this
#
# RETURNS
#   The edited command's exit status, or a message when history lookup
#   found nothing.
#
# EXAMPLE
#   fc
#   fc git
function fc --description 'Edit and execute the last command (Bash-style fc)'
    set -l tmpfile (mktemp /tmp/fish_fc.XXXXXX).fish

    if count $argv >/dev/null
        # Search for a specific previous command
        builtin history search --max=1 "$argv" | sed 's/^[0-9-]* [0-9:]* //' >$tmpfile
    else
        # Grab the last 2 commands, then take the 2nd one (the one before 'fc')
        # This avoids the --skip flag entirely
        builtin history --max=2 | sed 's/^[0-9-]* [0-9:]* //' | sed -n 2p >$tmpfile
    end

    # Set editor with fallback
    set -l editor $EDITOR
    if test -z "$editor"
        set editor vi
    end

    # Only open editor if we actually got a command
    if test -s $tmpfile
        $editor $tmpfile

        # Final check if user cleared the file in the editor
        if test -s $tmpfile
            set -l command (cat $tmpfile)
            rm $tmpfile
            commandline -r "$command"
            commandline -f execute
        else
            rm $tmpfile
            echo "fc: Aborted (empty file)"
        end
    else
        rm $tmpfile
        echo "fc: Could not retrieve history"
    end
end
