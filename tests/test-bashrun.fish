#!/usr/bin/env fish
# Copyright (C) 2026 Rootiest
# SPDX-License-Identifier: AGPL-3.0-or-later
#
# MODE: isolated
#
# Coverage for the Bash fallback on Enter: bashrun (runs Bash code and
# imports its exported variables and cwd), __bashrun_wanted (decides which
# command lines go to Bash) and __bashrun_execute (the Enter binding).
# `commandline` only works at a live prompt, so __bashrun_execute runs
# against a small model of it: a buffer, the validity status
# `commandline --is-valid` would report, and a log of `--function` calls.

source (realpath (dirname (status filename)))/lib.fish
set -p fish_function_path $repo_root/functions
set -gx NO_COLOR 1

set -g tmp (mktemp -d)

#   ──────── __bashrun_wanted ────────

section __bashrun_wanted

# want <expected> <fish-validity> <text>
function want --argument-names expected validity text
    __bashrun_wanted $validity $text; and set -l got bash; or set -l got fish
    check "$validity: $(string replace -a \n ' ⏎ ' -- $text)" $expected $got
end

want bash 2 'for f in *; do echo $f; done'
want bash 2 'if [ -f x ]; then echo y; fi'
want bash 2 'case $x in a) echo a;; esac'
want bash 2 "cat <<EOF
hi
EOF"
want bash 1 'echo ${HOME}'
want bash 1 'echo $?'
want bash 1 'x=$(date)'
want bash 1 '[[ -f x ]] && echo y'
want fish 0 'echo valid fish'
want fish 2 begin
want fish 2 'for x in a b'
want fish 2 'if true'
want fish 2 'begin; echo done'
want fish 2 'while true; do sleep 1'
want fish 1 'echo ('
want fish 1 '   '

#   ──────── bashrun ────────

section bashrun

set -gx KEEP keep
set -gx DROP drop
set -l out (bashrun 'for i in 1 2; do echo "i=$i"; done
export NEW="two
lines"; unset DROP; export PATH="/opt/bashrun-test:$PATH"; cd '$tmp'; exit 3')
set -l rc $status
check "output streams through" "i=1 i=2" "$out"
check "exit status is the code's" 3 $rc
check "new export imported, newlines kept" "two
lines" "$NEW"
check "unset variable erased" no (set -q DROP; and echo yes; or echo no)
check "untouched variable kept" keep "$KEEP"
check "PATH imported as a list" /opt/bashrun-test $PATH[1]
check "cwd carried back" (realpath $tmp) (realpath $PWD)

false
check "\$? starts from fish's last status" 1 (bashrun 'echo $?')
check "no code is a usage error" 2 (bashrun 2>/dev/null; echo $status)
check "-h prints help" 0 (bashrun -h >/dev/null; echo $status)
check "-- passes -h through as code" -h (bashrun -- 'printf %s -h')

#   ──────── __bashrun_execute ────────

section __bashrun_execute

set -g __cl_buf ''
set -g __cl_valid 0
set -g __cl_mode ''
set -g __cl_funcs

function commandline
    switch "$argv[1]"
        case --is-valid
            return $__cl_valid
        case --paging-mode
            test "$__cl_mode" = paging
        case --search-mode
            test "$__cl_mode" = search
        case -f
            set -a __cl_funcs $argv[2..-1]
        case -r
            set -g __cl_buf $argv[-1]
        case '*'
            printf '%s\n' $__cl_buf
    end
end

# press <validity> <buffer> [mode]
function press
    set -g __cl_valid $argv[1]
    set -g __cl_buf $argv[2]
    set -g __cl_mode "$argv[3]"
    set -g __cl_funcs
    __bashrun_execute
end

press 0 'echo fish'
check "valid fish is left alone" 'echo fish' "$__cl_buf"
check "and executes" execute "$__cl_funcs"

press 2 'for x in a b'
check "a fish block being typed is left alone" 'for x in a b' "$__cl_buf"

# Buffer: for f in *; do echo "it's $f"; done ⏎ echo \
press 2 'for f in *; do echo "it\'s $f"; done'\n'echo \\'
check "bash is rewritten, quotes and backslashes escaped" \
    'bashrun \'for f in *; do echo "it\\\'s $f"; done'\n'echo \\\\\'' "$__cl_buf"
check "then executes" execute "$__cl_funcs"

press 2 'for f in *; do echo; done' paging
check "pager open: untouched" 'for f in *; do echo; done' "$__cl_buf"

# The rewritten line must hand bash back the exact original text.
set -l original "printf '%s\n' \"a'b\" 'c\\d'"
press 1 "$original"
eval $__cl_buf >$tmp/rewritten
command bash -c $original >$tmp/direct
check "rewrite round-trips through bashrun" (cat $tmp/direct | string collect) (cat $tmp/rewritten | string collect)

command rm -rf $tmp
report
