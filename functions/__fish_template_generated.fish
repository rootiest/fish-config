# Copyright (C) 2026 Rootiest
# SPDX-License-Identifier: AGPL-3.0-or-later

# SYNOPSIS
#   __fish_template_generated DIR
#
# DESCRIPTION
#   Prints the names of the functions in DIR that fish-template made (files
#   carrying the recipe markers, see
#   __fish_template_is_generated), one per line.
#
# EXIT STATUS
#   0  Always
function __fish_template_generated --argument-names dir --description 'List functions made by fish-template'
    for f in $dir/*.fish
        __fish_template_is_generated $f
        and path change-extension '' (path basename -- $f)
    end
    return 0
end
