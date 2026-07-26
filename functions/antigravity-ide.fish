# Copyright (C) 2026 Rootiest
# SPDX-License-Identifier: AGPL-3.0-or-later

# CATEGORY
#   12-ai-and-developer-tools
#
# SYNOPSIS
#   antigravity-ide [args...]
#
# DESCRIPTION
#   Wrapper for the antigravity-ide command that filters a known noisy warning
#   about an unrecognized 'app' option from stderr.
#
# ARGUMENTS
#   args...  Arguments passed through to the antigravity-ide command
#
# EXAMPLE
#   antigravity-ide
function antigravity-ide --wraps='antigravity-ide' --description 'alias antigravity-ide=antigravity-ide'
    # In fish, we pipe stderr using '2>|' to another command
    command antigravity-ide $argv 2>| grep -v "'app' is not in the list of known options" >&2
end
