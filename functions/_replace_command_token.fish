# Copyright (C) 2026 Rootiest
# SPDX-License-Identifier: AGPL-3.0-or-later

# Removes the first token from the command line and places the cursor at the position for replacement.
# If the command starts with 'sudo', preserves 'sudo' and removes the next token instead.
function _replace_command_token --description 'Remove first command token (or first after sudo) and place cursor for replacement'
    set -l cmd (commandline)

    # 1. Logic for commands starting with sudo
    if string match -rq '^sudo\s+' -- "$cmd"
        # regex explanation: 
        # ^sudo\s+  -> Matches 'sudo' and the following whitespace
        # \S+       -> Matches the actual command (e.g., 'rm')
        # \s*       -> Consumes the space after the command so it's not captured
        # (.*)      -> Captures everything else (the arguments) into $1
        set -l rest (string replace -r '^sudo\s+\S+\s*(.*)' 'sudo  $1' -- "$cmd")
        commandline -- "$rest"

        # Place cursor between the two spaces after sudo
        # 'sudo ' is 5 characters (indices 0-4), so index 5 is the sweet spot
        commandline -C 5

        # 2. Logic for standard commands (no sudo)
    else
        # regex explanation:
        # ^\S+      -> Matches the first word/command
        # \s*       -> Consumes the trailing space
        # (.*)      -> Captures the rest of the line into $1
        set -l rest (string replace -r '^\S+\s*(.*)' ' $1' -- "$cmd")
        commandline -- "$rest"

        # Place cursor at index 0 to immediately start typing the replacement
        commandline -C 0
    end
end
