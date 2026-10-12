# Copyright (C) 2026 Rootiest
# SPDX-License-Identifier: AGPL-3.0-or-later

# SYNOPSIS
#   __fish_template_is_generated FILE
#
# DESCRIPTION
#   Tells whether FILE was made by fish-template: it must hold the recipe
#   start marker and the end marker, each alone on its own line (leading
#   whitespace allowed). The marker text merely quoted inside a string, as
#   in fish-template's own code, does not count.
#
# EXIT STATUS
#   0  FILE was made by fish-template
#   1  It was not, or it cannot be read
function __fish_template_is_generated --argument-names file --description 'Tell whether a file was made by fish-template'
    test -f "$file"; and test -r "$file"; or return 1
    set -l lines (string match -r -- '^\s*# ── (?:fish-template|end) recipe ──$' <$file | string trim)
    contains -- '# ── fish-template recipe ──' $lines; or return 1
    contains -- '# ── end recipe ──' $lines; or return 1
    return 0
end
