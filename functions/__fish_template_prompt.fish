# Copyright (C) 2026 Rootiest
# SPDX-License-Identifier: AGPL-3.0-or-later

# SYNOPSIS
#   __fish_template_prompt TEMPLATE KEY TYPE REQUIRED PROMPT
#
# DESCRIPTION
#   Asks for one setting on stdin and stores the checked answer. The
#   current value is the default: Enter keeps it, "-" clears it. A list
#   answer is split like fish arguments (quotes keep spaces). A lines
#   setting takes one entry per line until a blank line. Invalid answers
#   are explained and asked again.
#
# EXIT STATUS
#   0  Stored
#   1  End of input (the wizard treats this as cancel)
function __fish_template_prompt --argument-names tpl key type req prompt --description 'Ask for one fish-template setting'
    set -l v __ftv_$key
    set -l cur $$v
    if test "$type" = lines
        while true
            echo "  $tpl · $prompt (one per line, blank line to finish)"
            if set -q cur[1]
                printf '      %s\n' $cur
                set -l keep
                read -P "    Keep these? [Y/n] " keep; or return 1
                string match -qir '^n' -- "$keep"; or return 0
            end
            set -l items
            set -l item
            set -l eof 0
            while true
                if not read -P "    > " item
                    set eof 1
                    break
                end
                test -z "$item"; and break
                set -a items $item
            end
            if __fish_template_check $key lines $req $items >/dev/null
                __fish_template_store set $key $items
                return 0
            end
            test $eof -eq 1; and return 1
        end
    end

    set -l hint ''
    if string match -q 'choice:*' -- $type
        set hint " ("(string split -n ' ' -- (string replace -- choice: '' $type) | string join /)")"
    end
    set -l shown "$cur"
    test "$type" = list; and set shown (string join ' ' -- (string escape -- $cur))
    while true
        set -l ans
        read -P "  $tpl · $prompt$hint [$shown]: " ans; or return 1
        set -l vals
        if test -z "$ans"
            set vals $cur
        else if test "$ans" = -
            set vals
        else if test "$type" = list
            printf '%s\n' $ans | read -at vals
        else
            set vals $ans
        end
        set -l norm (__fish_template_check $key $type $req $vals)
        if test $status -eq 0
            __fish_template_store set $key $norm
            return 0
        end
    end
end
