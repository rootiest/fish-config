# Copyright (C) 2026 Rootiest
# SPDX-License-Identifier: AGPL-3.0-or-later

# SYNOPSIS
#   __fish_color <set_color arguments...>
#
# DESCRIPTION
#   NO_COLOR-aware replacement for a bare set_color call, for the colour
#   producers that cannot take their colours from __fish_palette (they use
#   a specific colour or attribute rather than a palette role, so routing
#   them through a role would change what the user sees).
#
#   Always called inside a command substitution, and always yields exactly
#   ONE element: the escape sequence set_color would print, or the empty
#   string when NO_COLOR is set to a non-empty value (https://no-color.org;
#   an empty value does not count) or when set_color itself prints nothing
#   (TERM=dumb). One element matters: a command substitution that prints
#   nothing is an EMPTY LIST, and an empty list in a concatenation such as
#   (set_color red)"text" annihilates the whole word, so the message would
#   vanish exactly where colour is off.
#
#   Two call shapes replace the old forms:
#     echo (set_color red)"oops"(set_color normal)
#       becomes  echo (__fish_color red)"oops"(__fish_color normal)
#     set_color yellow      (a bare statement printing the escape)
#       becomes  echo -n (__fish_color yellow)
#
# ARGUMENTS
#   set_color arguments   Passed through unchanged (colours, --bold, ...)
#
# EXIT STATUS
#   0  always
#
# EXAMPLE
#   echo (__fish_color red)"Error:"(__fish_color normal) "no such file" >&2
#
# NOTES
#   Call it as a command substitution only. Run bare, it prints a newline
#   after the escape sequence.
function __fish_color --description 'set_color that honours NO_COLOR and always yields one element'
    set -l seq
    test -n "$NO_COLOR"; or set seq (set_color $argv 2>/dev/null)
    echo "$seq"
    return 0
end
