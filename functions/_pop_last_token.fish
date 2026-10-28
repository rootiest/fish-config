# Copyright (C) 2026 Rootiest
# SPDX-License-Identifier: AGPL-3.0-or-later

# SYNOPSIS
#   _pop_last_token
#
# DESCRIPTION
#   Removes the last token (argument) from the commandline buffer and leaves
#   the cursor at the end of what remains, after one trailing space, ready to
#   retype it. Repeated presses pop consecutive arguments. Quoted and
#   backslash-escaped arguments pop as a single token. The command word is
#   never removed (nor "sudo" and the command after it): that is
#   _replace_command_token's job, so popping stops there. If the commandline
#   is empty, first recalls the most recent history entry (like pressing Up)
#   before popping. Intended to be bound to a key in key_bindings.fish.
#
# EXAMPLE
#   bind ctrl-alt-w _pop_last_token
function _pop_last_token --description 'Remove the last argument and place the cursor where it was'
    set -l cmd (commandline)

    # Empty prompt: recall the last history entry first, same as
    # _replace_command_token does.
    if string match -rq '^\s*$' -- "$cmd"
        set cmd (builtin history --max 1)
    end

    set -l trimmed (string replace -r '\s+$' '' -- "$cmd")

    # A token is any run of double-quoted strings, single-quoted strings,
    # backslash escapes, and plain non-space characters ending the buffer.
    set -l dq '"(?:[^"\\\\]|\\\\.)*"'
    set -l sq "'[^']*'"
    set -l tok "(?:$dq|$sq|\\\\.|[^\\s\"'\\\\])+"
    set -l rest (string replace -r "$tok"'$' '' -- "$trimmed")

    # Unterminated quote: nothing above matched, so fall back to the last
    # run of non-space characters.
    if test "$rest" = "$trimmed"
        set rest (string replace -r '\S+$' '' -- "$trimmed")
    end

    # Never pop the command word (or "sudo" plus the command after it).
    set -l head (string trim -- "$rest")
    if test -z "$head"; or test "$head" = sudo
        return 0
    end

    # Keep exactly one trailing space as the gap for the replacement.
    set -l new (string replace -r '\s+$' '' -- "$rest")" "
    commandline -- "$new"
    commandline -C (string length -- "$new")
    return 0
end
