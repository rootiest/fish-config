# Copyright (C) 2026 Rootiest
# SPDX-License-Identifier: AGPL-3.0-or-later

# SYNOPSIS
#   __fish_template_fragment FILE PHASE
#
# DESCRIPTION
#   Prints the code template FILE contributes to PHASE (guard, seed,
#   prepare, run or finally): the lines under its `Fragment: PHASE`
#   banner, or under a bare `Fragment` banner when its PHASE metadata
#   names PHASE. Leading and trailing blank lines are dropped.
#
# EXIT STATUS
#   0  The template has a fragment for PHASE
#   1  It does not
function __fish_template_fragment --argument-names file phase --description 'Print one phase fragment of a fish-template template'
    set -l bare (__fish_template_meta $file PHASE)
    set -l out
    set -l inside 0
    while read -l line
        if string match -qr -- '^#\s+─+ Fragment(: [a-z]+)? ─+$' $line
            set -l p (string match -r --groups-only -- 'Fragment: ([a-z]+)' $line)
            set -q p[1]; or set p $bare
            if test "$p" = "$phase"
                set inside 1
            else
                set inside 0
            end
            continue
        end
        test $inside -eq 1; and set -a out $line
    end <$file
    while set -q out[1]; and string match -qr '^\s*$' -- $out[1]
        set -e out[1]
    end
    while set -q out[1]; and string match -qr '^\s*$' -- $out[-1]
        set -e out[-1]
    end
    set -q out[1]; or return 1
    printf '%s\n' $out
end
