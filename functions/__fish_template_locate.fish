# Copyright (C) 2026 Rootiest
# SPDX-License-Identifier: AGPL-3.0-or-later

# SYNOPSIS
#   __fish_template_locate NAME DIR
#
# DESCRIPTION
#   Prints the file of function NAME if fish-template made it: DIR/NAME.fish
#   first, then wherever fish would load NAME from. Only a file named
#   NAME.fish that carries the recipe markers (__fish_template_is_generated)
#   is returned, so edit/regen/show cannot touch a hand-written function.
#
# EXIT STATUS
#   0  Found
#   1  Not a function made by fish-template (message on stderr)
function __fish_template_locate --argument-names name dir --description 'Find a function made by fish-template'
    for f in $dir/$name.fish (functions -D -- $name 2>/dev/null)
        test "$(path basename -- $f)" = "$name.fish"; or continue
        if __fish_template_is_generated $f
            echo $f
            return 0
        end
    end
    echo "fish-template: $name is not a function made by fish-template" >&2
    return 1
end
