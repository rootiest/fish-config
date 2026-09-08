# Copyright (C) 2026 Rootiest
# SPDX-License-Identifier: AGPL-3.0-or-later

# CATEGORY
#   06-dependency-management
#
# SYNOPSIS
#   check_fish_deps
#
# DESCRIPTION
#   Backwards-compatibility wrapper that delegates to fish-deps status to
#   report which fish shell dependencies are installed or missing.
#
# EXIT STATUS
#   Exit status of `fish-deps status`
#
# EXAMPLE
#   check_fish_deps
function check_fish_deps --description 'Check all fish-related dependencies'
    __fish_help_header (status current-function) $argv; and return 0

    fish-deps status
end
