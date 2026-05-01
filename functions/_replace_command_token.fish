# Copyright (C) 2026 Rootiest
# SPDX-License-Identifier: AGPL-3.0-or-later

# Removes the first token from the command line and places the cursor at the start
function _replace_command_token --description 'Remove first token from commandline and place cursor at start'
    set -l cmd (commandline)
    set -l rest (string replace -r '^\S+' '' -- $cmd)
    commandline -- $rest
    commandline -C 0
end
