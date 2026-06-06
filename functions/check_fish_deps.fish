# Copyright (C) 2026 Rootiest
# SPDX-License-Identifier: AGPL-3.0-or-later

# SYNOPSIS
#   check_fish_deps
#
# DESCRIPTION
#   Backwards-compatibility wrapper that delegates to fish-deps status to
#   report which fish shell dependencies are installed or missing.
#
# EXAMPLE
#   check_fish_deps
function check_fish_deps --description 'Check all fish-related dependencies'
    fish-deps status
end
