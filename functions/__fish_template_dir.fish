# Copyright (C) 2026 Rootiest
# SPDX-License-Identifier: AGPL-3.0-or-later

# SYNOPSIS
#   __fish_template_dir
#
# DESCRIPTION
#   Prints the templates/ directory shipped next to this config's
#   functions/. $__fish_template_root overrides it (the tests use this).
function __fish_template_dir --description 'Print the fish-template templates directory'
    if set -q __fish_template_root[1]
        echo $__fish_template_root
        return 0
    end
    path resolve (path dirname (functions -D __fish_template_dir))/../templates
end
