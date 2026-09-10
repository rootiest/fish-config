# Copyright (C) 2026 Rootiest
# SPDX-License-Identifier: AGPL-3.0-or-later

# SYNOPSIS
#   _mkrep_say <silent> <message>
#
# DESCRIPTION
#   Prints <message> unless <silent> is 1. Used by mkrep for its default
#   per-step summary lines, which -s/--silent must suppress entirely.
#
# ARGUMENTS
#   silent    1 to suppress output, 0 to print
#   message   Text to print (echo -e, so escapes/colour codes render)
#
# EXIT STATUS
#   0  always
function _mkrep_say --argument-names silent msg
    test "$silent" = 1; and return 0
    echo -e $msg
end
