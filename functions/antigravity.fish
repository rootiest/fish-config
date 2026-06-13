# Copyright (C) 2026 Rootiest
# SPDX-License-Identifier: AGPL-3.0-or-later

# SYNOPSIS
#   antigravity [args...]
#
# DESCRIPTION
#   Wrapper for the agy Antigravity AI CLI that filters a known noisy warning
#   about an unrecognized 'app' option from stderr.
#
# ARGUMENTS
#   args...  Arguments passed through to the agy command
#
# EXAMPLE
#   antigravity chat
function antigravity --wraps='agy' --description 'alias antigravity=agy'
    # In fish, we pipe stderr using '2>|' to another command
    agy $argv 2>| grep -v "'app' is not in the list of known options" >&2
end
