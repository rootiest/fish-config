# Copyright (C) 2026 Rootiest
# SPDX-License-Identifier: AGPL-3.0-or-later

# CATEGORY
#   10-network
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
# EXAMPLE
#   fast-cli
function fast-cli --description "Run a speed test using fast.com"
    command fast $argv
end
