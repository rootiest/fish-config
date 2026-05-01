# Copyright (C) 2026 Rootiest
# SPDX-License-Identifier: AGPL-3.0-or-later

# Function for installing packages with paru.
# This runs `paru` with the `-S` flag to install one or more packages.
# The `$argv` variable passes all arguments given to the `pkg` function
# directly to the `paru` command.
function pkg --wraps='paru' --description 'directly to the `paru` command.'
    paru -S $argv
end
