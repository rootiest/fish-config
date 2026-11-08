# Copyright (C) 2026 Rootiest
# SPDX-License-Identifier: AGPL-3.0-or-later

# CLASSIFICATION
#   blocking-prompt
#
# SYNOPSIS
#   _fish_deps_ask QUESTION
#
# DESCRIPTION
#   Asks a yes/no/quit question for the fish-deps installer and reports the
#   answer through its exit status. The prompt reads [Y/n/q]: an empty
#   answer or y accepts, n declines this one step, and q abandons the
#   whole run.
#
#   Ctrl+C and Ctrl+D make read fail with an empty answer, which the old
#   [Y/n] prompt mistook for the default "yes". Here a failed read is a
#   quit, and so is an interrupt already recorded in $_fdc_cancelled, so the
#   caller never carries on to the next step after a cancellation.
#
#   Anything that is not y, n or q is asked again.
#
#   When $_fdc_assume_yes is 1 (fish-deps install --yes), the question is
#   printed with its default answer and accepted without reading input, so
#   a scripted run never waits on stdin.
#
# ARGUMENTS
#   QUESTION  The question to show, without the trailing [Y/n/q]
#
# EXIT STATUS
#   0  Accepted (or taken as the default under --yes)
#   1  Declined this step
#   2  Quit requested (q, Ctrl+C, Ctrl+D, or an earlier interrupt)
#
# EXAMPLE
#   _fish_deps_ask "Install starship?"
function _fish_deps_ask --argument-names question
    test "$_fdc_cancelled" = 1; and return 2
    __fish_palette

    if test "$_fdc_assume_yes" = 1
        echo "$c_arg$question$c_reset [Y/n/q] y (--yes)"
        return 0
    end

    while true
        read -l -P "$c_arg$question$c_reset [Y/n/q] " reply
        or return 2
        test "$_fdc_cancelled" = 1; and return 2

        switch (string lower -- "$reply")
            case '' y yes
                return 0
            case n no
                return 1
            case q quit
                return 2
        end
        echo "  Please answer y, n or q." >&2
    end
end
