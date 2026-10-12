# Copyright (C) 2026 Rootiest
# SPDX-License-Identifier: AGPL-3.0-or-later

# SYNOPSIS
#   __fish_template_locate NAME DIR
#
# DESCRIPTION
#   Prints the file of function NAME if fish-template made it: DIR/NAME.fish
#   first, then wherever fish would load NAME from. A file without the
#   recipe marker is never returned, so edit/regen/show cannot touch a
#   hand-written function.
#
# EXIT STATUS
#   0  Found
#   1  Not a function made by fish-template (message on stderr)
function __fish_template_locate --argument-names name dir --description 'Find a function made by fish-template'
    for f in $dir/$name.fish (functions -D -- $name 2>/dev/null)
        test -f "$f"; or continue
        if string match -q -- '*# ── fish-template recipe ──*' <$f
            echo $f
            return 0
        end
    end
    echo "fish-template: $name is not a function made by fish-template" >&2
    return 1
end
