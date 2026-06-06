# Copyright (C) 2026 Rootiest
# SPDX-License-Identifier: AGPL-3.0-or-later

# SYNOPSIS
#   less [args...]
#
# DESCRIPTION
#   Pager wrapper that tries $PAGER, then ov, then less, then more, then cat
#   as fallbacks in that order.
#
# ARGUMENTS
#   args...  Files or options forwarded to the pager
#
# EXAMPLE
#   less /var/log/syslog
function less --wraps='ov' --description 'Pager wrapper: $PAGER → ov → less → more → cat'
    if set -q PAGER; and command -q $PAGER
        command $PAGER $argv
    else if command -q ov
        command ov $argv
    else if command -q less
        command less $argv
    else if command -q more
        command more $argv
    else
        command cat $argv
    end
end
