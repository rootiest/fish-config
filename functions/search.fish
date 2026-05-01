# Copyright (C) 2026 Rootiest
# SPDX-License-Identifier: AGPL-3.0-or-later

# Function for searching for packages to install with paru.
# This runs `paru` with the search flags.
# The `$argv` variable passes all arguments given to the `search` function
# directly to the `paru` command.
function search --wraps='paru' --description 'directly to the `paru` command.'
    paru $argv
end
