# Copyright (C) 2026 Rootiest
# SPDX-License-Identifier: AGPL-3.0-or-later

# CATEGORY
#   10-network
#
# DEPENDENCIES
#   fast
#
# SYNOPSIS
#   fast-cli [args...]
#
# DESCRIPTION
#   Runs a network speed test using the fast.com CLI tool.
#
# ARGUMENTS
#   args...  Arguments forwarded to the fast command
#
# EXIT STATUS
#   1  fast is not installed
#   *  Exit status of fast otherwise
#
# EXAMPLE
#   fast-cli
function fast-cli --description "Run a speed test using fast.com"
    if not type -q -f fast
        echo (set_color red)"Error: fast is not installed."(set_color normal) >&2
        return 1
    end
    command fast $argv
end
