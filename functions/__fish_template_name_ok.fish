# Copyright (C) 2026 Rootiest
# SPDX-License-Identifier: AGPL-3.0-or-later

# SYNOPSIS
#   __fish_template_name_ok NAME
#
# DESCRIPTION
#   Says whether NAME can be a generated function's name: it must match
#   the function-name rule and fish must accept it in a function
#   definition (keywords and builtins such as set, end and test are
#   refused by fish). Prints nothing; used by __fish_template_new and the
#   wizard so the rule lives in one place.
#
# EXIT STATUS
#   0  NAME is usable
#   1  NAME is not usable
function __fish_template_name_ok --argument-names name --description 'Check a fish-template function name'
    string match -qr '^[A-Za-z0-9_][A-Za-z0-9_.+-]*$' -- "$name"; or return 1
    fish --no-config -c "function $name; end" 2>/dev/null
    return $status
end
