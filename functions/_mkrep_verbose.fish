# Copyright (C) 2026 Rootiest
# SPDX-License-Identifier: AGPL-3.0-or-later

# SYNOPSIS
#   _mkrep_verbose <silent> <verbose> <message>
#
# DESCRIPTION
#   Prints <message> only when <verbose> is 1 and <silent> is 0. Used by
#   mkrep for the extra step-by-step tracing -v/--verbose adds.
#
# ARGUMENTS
#   silent    1 to suppress output, 0 to allow it
#   verbose   1 to print, 0 to stay quiet
#   message   Text to print (echo -e, so escapes/colour codes render)
#
# EXIT STATUS
#   0  always
function _mkrep_verbose --argument-names silent verbose msg
    test "$silent" = 1; and return 0
    test "$verbose" = 1; or return 0
    echo -e $msg
end
