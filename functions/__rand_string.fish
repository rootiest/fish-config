# Copyright (C) 2026 Rootiest
# SPDX-License-Identifier: AGPL-3.0-or-later

# SYNOPSIS
#   __rand_string [COMPONENTS/MODIFIERS]...
#
# DESCRIPTION
#   Generates a random, memorable string using a sequence of specified word
#   categories and formatting modifiers. Words are pulled from curated
#   plain-text databases bundled in `data/words/`.
#
#   Modifiers like `--separator` and `--case` are evaluated sequentially and
#   apply only to the components that follow them.
#
#   Supported Components:
#   <category>      A bundled word list (e.g. adjective, animal, color, name, noun)
#   digits=<N>      N random digits (e.g. digits=3 -> 842)
#   literal=<text>  A literal string component
#
# ARGUMENTS
#   -s, --separator=<sep>   Delimiter for subsequent words (dash, underscore, dot, none, or literal chars)
#   -c, --case=<casing>     Casing for subsequent words (lower, upper, title)
#
# EXIT STATUS
#   0  String generated successfully
#   1  Unknown category or missing word list file
#
# EXAMPLE
#   __rand_string adjective animal
#   __rand_string --case=title color animal --separator=dot digits=4
#
# NOTES
#   Falls back to `random choice` if GNU `shuf` is missing, but `shuf` is
#   much faster for files with >1000 lines.
function __rand_string --description 'Generate random, memorable strings from curated word databases'
    set -l sep "dash"
    set -l casing "lower"
    
    # Locate the words directory relative to this function
    set -l words_dir ""
    if set -q __fish_config_dir
        set words_dir "$__fish_config_dir/data/words"
    else
        # Fallback if __fish_config_dir isn't available
        set words_dir "$HOME/.config/fish/data/words"
    end

    set -l result ""
    set -l i 1

    while test $i -le (count $argv)
        set -l arg $argv[$i]
        set -l handled 0

        # 1. Parse inline modifiers
        switch $arg
            case -s --separator
                set i (math $i + 1)
                set sep $argv[$i]
                set handled 1
            case '--separator=*'
                set sep (string replace -- "--separator=" "" $arg)
                set handled 1
            case '-s*'
                set sep (string replace -r "^-s" "" $arg)
                set handled 1
            case -c --case
                set i (math $i + 1)
                set casing $argv[$i]
                set handled 1
            case '--case=*'
                set casing (string replace -- "--case=" "" $arg)
                set handled 1
            case '-c*'
                set casing (string replace -r "^-c" "" $arg)
                set handled 1
        end

        if test $handled -eq 1
            set i (math $i + 1)
            continue
        end

        # 2. Resolve separator alias
        set -l actual_sep $sep
        switch $sep
            case dash
                set actual_sep "-"
            case underscore
                set actual_sep "_"
            case dot
                set actual_sep "."
            case none empty
                set actual_sep ""
        end

        # 3. Generate the component part
        set -l part ""
        switch $arg
            case 'digits=*'
                set -l n (string replace -- "digits=" "" $arg)
                if not string match -qr '^\d+$' -- $n
                    set n 1
                end
                for idx in (seq $n)
                    set part "$part"(random 0 9)
                end
            case 'literal=*'
                set part (string replace -- "literal=" "" $arg)
            case 'string=*'
                set part (string replace -- "string=" "" $arg)
            case '*'
                set -l db "$words_dir/$arg.txt"
                if not test -f "$db"
                    echo "__rand_string: unknown category or file missing for '$arg'" >&2
                    return 1
                end
                
                # Fetch random line (shuf is fastest, random choice is portable fallback)
                if command -q shuf
                    set part (command shuf -n 1 "$db")
                else
                    set part (random choice (command cat "$db"))
                end
        end

        # 4. Apply casing
        switch $casing
            case upper
                set part (string upper $part)
            case lower
                set part (string lower $part)
            case title
                set part (string replace -r '^(.)' '\U$1' (string lower $part))
        end

        # 5. Append to result
        if test -n "$result"
            set result "$result$actual_sep$part"
        else
            set result "$part"
        end

        set i (math $i + 1)
    end

    if test -n "$result"
        echo $result
    end
end
