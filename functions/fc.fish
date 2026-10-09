# Copyright (C) 2026 Rootiest
# SPDX-License-Identifier: AGPL-3.0-or-later

# CATEGORY
#   03-editors-and-viewers
#
# CLASSIFICATION
#   bypasses-shadow(rm), self-limiting(cat)
#
# SYNOPSIS
#   fc [command_prefix]
#
# DESCRIPTION
#   Edits the last shell command -- or the most recent one matching a
#   prefix -- in $EDITOR, then executes the result. Bash-style fc
#   behaviour. $EDITOR may carry arguments (e.g. "code --wait"); falls back
#   to vi when unset. Multi-line commands keep their newlines, the scratch
#   file is private (mode 600) and always removed, and an empty buffer
#   aborts without executing.
#
# ARGUMENTS
#   command_prefix   Search history for the newest command matching this
#
# EXIT STATUS
#   0  The edited command was queued for execution
#   1  History lookup found nothing, or the buffer was left empty
#
# EXAMPLE
#   fc
#   fc git
function fc --description 'Edit and execute the last command (Bash-style fc)'
    __fish_help_header (status current-function) $argv; and return 0

    # One private (mode 600) scratch file; the .fish suffix lets editors
    # highlight it. Honours $TMPDIR.
    set -l tmpfile (mktemp --suffix=.fish)
    or begin
        echo "fc: could not create a temporary file" >&2
        return 1
    end

    # --null keeps multi-line history entries in one piece.
    set -l entry
    if count $argv >/dev/null
        # Search for a specific previous command
        set entry (builtin history search --max=1 --null "$argv" | string split0 -n)
    else
        # Grab the last 2 commands, then take the 2nd one (the one before 'fc')
        # This avoids the --skip flag entirely
        set entry (builtin history --max=2 --null | string split0 -f2)
    end

    # Only open the editor if we actually got a command
    if not set -q entry[1]
        command rm -f $tmpfile
        echo "fc: Could not retrieve history" >&2
        return 1
    end
    printf '%s\n' $entry >$tmpfile

    # $EDITOR may be several words ("code --wait"); fall back to vi.
    set -l editor
    echo $EDITOR | read -at editor
    set -q editor[1]; or set editor vi
    $editor $tmpfile

    set -l lines (cat $tmpfile)
    command rm -f $tmpfile

    # Final check if user cleared the file in the editor
    if not set -q lines[1]
        echo "fc: Aborted (empty file)" >&2
        return 1
    end

    commandline -r -- (string join \n -- $lines | string collect)
    commandline -f execute
    return 0
end
