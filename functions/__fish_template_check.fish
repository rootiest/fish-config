# Copyright (C) 2026 Rootiest
# SPDX-License-Identifier: AGPL-3.0-or-later

# SYNOPSIS
#   __fish_template_check KEY TYPE REQUIRED [VALUE...]
#
# DESCRIPTION
#   Validates one setting's values against its type and prints them
#   normalized, one per line: a leading ~ in a path becomes $HOME, and a
#   bool becomes true or false. list and lines take any number of values;
#   every other type takes at most one. REQUIRED 1 rejects an empty value.
#
# EXIT STATUS
#   0  Valid (the normalized values are on stdout)
#   1  Invalid; "fish-template: KEY: reason" is on stderr
function __fish_template_check --argument-names key type req --description 'Validate one fish-template setting'
    set -l vals $argv[4..]
    set -l msg
    set -l multi 0
    contains -- $type list lines; and set multi 1
    if test "$req" = 1; and test -z "$vals"
        set msg "a value is required"
    else if test $multi -eq 0; and set -q vals[2]
        set msg "expects a single value, got "(count $vals)
    else if test $multi -eq 0; and set -q vals[1]
        switch $type
            case int
                string match -qr '^[0-9]+$' -- $vals[1]
                or set msg "expects a whole number, got '$vals[1]'"
            case bool
                switch (string lower -- "$vals[1]")
                    case y yes true on 1
                        set vals true
                    case n no false off 0
                        set vals false
                    case '*'
                        set msg "expects yes or no, got '$vals[1]'"
                end
            case path
                set vals (string replace -r -- '^~(?=/|$)' $HOME $vals[1])
            case 'choice:*'
                set -l opts (string split -n ' ' -- (string replace -- choice: '' $type))
                contains -- $vals[1] $opts
                or set msg "expects one of: $opts"
        end
    end
    if set -q msg[1]
        echo "fish-template: $key: $msg" >&2
        return 1
    end
    set -q vals[1]; and printf '%s\n' $vals
    return 0
end
