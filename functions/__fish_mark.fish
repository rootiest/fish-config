# Copyright (C) 2026 Rootiest
# SPDX-License-Identifier: AGPL-3.0-or-later

# SYNOPSIS
#   __fish_mark <ok | err | warn> [glyph]
#
# DESCRIPTION
#   Status mark for user-facing output: the glyph normally, a text label when
#   NO_COLOR is set to a non-empty value (https://no-color.org; an empty value
#   does not count). With colour on, the glyph's colour tells success from
#   failure at a glance; with colour off, ✔ and ✘ are left to carry that alone,
#   and to a screen reader or a grep they are not a word. The label is.
#
#     kind   glyph   NO_COLOR label
#     ok     ✔       [ok]
#     err    ✘       [error]
#     warn   ⚠       [warn]
#
#   Like __fish_color, it always yields exactly ONE element, so it can sit in
#   a concatenation: "$c_ok"(__fish_mark ok)"$c_reset  Done".
#
# ARGUMENTS
#   kind    ok, err or warn
#   glyph   Optional: the glyph to print instead of the default (for callers
#           that use ✓/✗). Ignored under NO_COLOR.
#
# EXIT STATUS
#   0  always
#
# EXAMPLE
#   echo "$c_err"(__fish_mark err)"$c_reset  Failed to add remote" >&2
#
# NOTES
#   Call it as a command substitution only. An unknown kind yields its name
#   in brackets under NO_COLOR, and the glyph argument (or nothing) otherwise.
function __fish_mark --argument-names kind glyph --description 'Status glyph, or a text label under NO_COLOR'
    if test -n "$NO_COLOR"
        switch $kind
            case err
                echo "[error]"
            case '*'
                echo "[$kind]"
        end
        return 0
    end
    if test -z "$glyph"
        switch $kind
            case ok
                set glyph ✔
            case err
                set glyph ✘
            case warn
                set glyph ⚠
        end
    end
    echo "$glyph"
    return 0
end
