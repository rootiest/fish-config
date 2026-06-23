# Copyright (C) 2026 Rootiest
# SPDX-License-Identifier: AGPL-3.0-or-later

# SYNOPSIS
#   config-toggle [args...]
#
# DESCRIPTION
#   Deprecated alias for config-settings. Prints a one-line deprecation
#   notice to stderr, then delegates all arguments to config-settings.
#
# ARGUMENTS
#   args  Passed through verbatim to config-settings
#
# RETURNS
#   Same as config-settings
#
# EXAMPLE
#   config-toggle        # opens config-settings with a deprecation notice
function config-toggle --description 'Deprecated alias for config-settings'
    echo "config-toggle is deprecated, use config-settings instead" >&2
    config-settings $argv
end
