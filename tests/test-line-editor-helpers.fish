#!/usr/bin/env fish
# Copyright (C) 2026 Rootiest
# SPDX-License-Identifier: AGPL-3.0-or-later
#
# MODE: isolated
#
# Coverage for the key-binding helpers that edit the command line (issue
# #238): the vendored autopair inserts and backspace, puffer-fish's `!$` and
# `!*` expansions, __insert_previous_path_head, __interactive_history_sub,
# and the Enter dispatcher _smart_execute with its qalc evaluator _qalc_eval.
#
# Runs isolated. None of these work outside an interactive prompt, so
# `commandline` is replaced by a small model of the line editor: a buffer, a
# cursor, an optional search field, and a log of every `--function` it was
# asked to run. qalc is a stub script on $PATH. Several helpers read the
# read-only $history variable, which cannot be faked, so the suite re-executes
# itself in a child fish whose XDG_DATA_HOME / XDG_CONFIG_HOME / HOME point
# into a temp dir and seeds a throwaway history session there. XDG_DATA_HOME
# is only read at startup, hence the re-exec rather than a `set -gx`.

if not set -q __FISH_CONFIG_LINE_EDITOR_SANDBOX
    set -l sb (mktemp -d)
    mkdir -p $sb/data $sb/cfg $sb/home
    env __FISH_CONFIG_LINE_EDITOR_SANDBOX=$sb XDG_DATA_HOME=$sb/data \
        XDG_CONFIG_HOME=$sb/cfg HOME=$sb/home \
        fish --no-config (status filename)
    set -l rc $status
    command rm -rf $sb
    exit $rc
end

source (realpath (dirname (status filename)))/lib.fish
set -p fish_function_path $repo_root/functions

set -l sandbox $__FISH_CONFIG_LINE_EDITOR_SANDBOX
set -g fish_history line_editor_test

# The autopair tables conf.d/autopair.fish defines.
set -g autopair_left "(" "[" "{" '"' "'"
set -g autopair_right ")" "]" "}" '"' "'"
set -g autopair_pairs "()" "[]" "{}" '""' "''"

#   ──────── commandline model ────────

set -g __cl_buf ''
set -g __cl_cur 0
set -g __cl_search # non-empty list = search field active; [2] is its text
set -g __cl_funcs

# cl_set BUFFER [CURSOR] : reset the model (cursor defaults to end of line).
function cl_set
    set -g __cl_buf "$argv[1]"
    if set -q argv[2]
        set -g __cl_cur $argv[2]
    else
        set -g __cl_cur (string length -- "$argv[1]")
    end
    set -g __cl_search
    set -g __cl_funcs
end

function __cl_token_bounds
    set -l before (string sub --length=$__cl_cur -- "$__cl_buf")
    set -l after (string sub --start=(math $__cl_cur + 1) -- "$__cl_buf")
    set -l head (string replace -r -- '^.*\s' '' "$before")
    set -l tail (string replace -r -- '\s.*$' '' "$after")
    set -l start (math $__cl_cur - (string length -- "$head"))
    echo $start
    echo (math $__cl_cur + (string length -- "$tail"))
end

function commandline
    argparse b/current-buffer C/cursor c/cut-at-cursor i/insert r/replace \
        f/function S/search-field t/current-token -- $argv
    or return 2

    if set -q _flag_function
        set -a __cl_funcs $argv
        for fn in $argv
            switch $fn
                case delete-char
                    set -g __cl_buf (string sub --length=$__cl_cur -- "$__cl_buf")(string sub --start=(math $__cl_cur + 2) -- "$__cl_buf")
                case backward-delete-char
                    if test $__cl_cur -gt 0
                        set -g __cl_buf (string sub --length=(math $__cl_cur - 1) -- "$__cl_buf")(string sub --start=(math $__cl_cur + 1) -- "$__cl_buf")
                        set -g __cl_cur (math $__cl_cur - 1)
                    end
            end
        end
        return 0
    end

    if set -q _flag_search_field
        set -q __cl_search[1]; or return 1
        if set -q _flag_insert
            set -g __cl_search[2] "$__cl_search[2]$argv"
        else
            echo $__cl_search[2]
        end
        return 0
    end

    if set -q _flag_cursor
        if set -q argv[1]
            set -g __cl_cur $argv[1]
        else
            echo $__cl_cur
        end
        return 0
    end

    if set -q _flag_insert
        set -l text (string join '' -- $argv)
        set -l before (string sub --length=$__cl_cur -- "$__cl_buf")
        set -l after (string sub --start=(math $__cl_cur + 1) -- "$__cl_buf")
        set -g __cl_buf "$before$text$after"
        set -g __cl_cur (math $__cl_cur + (string length -- "$text"))
        return 0
    end

    if set -q _flag_replace
        set -g __cl_buf (string join '' -- $argv)
        set -g __cl_cur (string length -- "$__cl_buf")
        return 0
    end

    if set -q _flag_current_token
        set -l b (__cl_token_bounds)
        if set -q argv[1]
            set -l text (string join '' -- $argv)
            set -g __cl_buf (string sub --length=$b[1] -- "$__cl_buf")"$text"(string sub --start=(math $b[2] + 1) -- "$__cl_buf")
            set -g __cl_cur (math $b[1] + (string length -- "$text"))
        else
            string sub --start=(math $b[1] + 1) --length=(math $b[2] - $b[1]) -- "$__cl_buf"
        end
        return 0
    end

    if set -q _flag_cut_at_cursor
        string sub --length=$__cl_cur -- "$__cl_buf"
        return 0
    end

    echo $__cl_buf
end

#   ──────── _autopair_insert_left ────────

section _autopair_insert_left

cl_set ''
_autopair_insert_left "(" ")"
check "empty line: ( inserts the pair" "()" "$__cl_buf"
check "empty line: cursor lands between the pair" 1 $__cl_cur

cl_set 'echo ' 5
_autopair_insert_left "[" "]"
check "after a space at end: [ inserts the pair" "echo []" "$__cl_buf"
check "cursor between [ and ]" 6 $__cl_cur

cl_set foo 0
_autopair_insert_left "(" ")"
check "before a word: only ( is inserted" "(foo" "$__cl_buf"
check "cursor after the lone (" 1 $__cl_cur

cl_set 'x)' 1
_autopair_insert_left "{" "}"
check "before a closing bracket: pair inserted" "x{})" "$__cl_buf"

#   ──────── _autopair_insert_right ────────

section _autopair_insert_right

cl_set '()' 1
_autopair_insert_right ")"
check "typing ) before ) skips over it" "()" "$__cl_buf"
check "cursor moved past the existing )" 2 $__cl_cur

cl_set foo 3
_autopair_insert_right "]"
check "typing ] elsewhere inserts it" "foo]" "$__cl_buf"
check "cursor advances after insert" 4 $__cl_cur

cl_set '(a]' 2
_autopair_insert_right ")"
check "mismatched next char: ) inserted, not skipped" "(a)]" "$__cl_buf"

#   ──────── _autopair_insert_same ────────

section _autopair_insert_same

cl_set ''
_autopair_insert_same '"'
check "empty line: \" inserts a pair" '""' "$__cl_buf"
check "cursor between the quotes" 1 $__cl_cur

cl_set '""' 1
_autopair_insert_same '"'
check "typing \" before a closing \" skips over it" '""' "$__cl_buf"
check "cursor moved past the closing quote" 2 $__cl_cur

cl_set 'echo "abc' 9
_autopair_insert_same '"'
check "odd quote count: a single closing quote is inserted" 'echo "abc"' "$__cl_buf"

cl_set abc 3
_autopair_insert_same "'"
check "after a word: only one quote (apostrophe)" "abc'" "$__cl_buf"

#   ──────── _autopair_backspace ────────

section _autopair_backspace

cl_set '()' 1
_autopair_backspace
check "inside an empty pair: both halves deleted" "" "$__cl_buf"
check "delete-char ran before backward-delete-char" "delete-char backward-delete-char" "$__cl_funcs"

cl_set '(x' 1
_autopair_backspace
check "not a pair: only the left char deleted" x "$__cl_buf"
check "only backward-delete-char ran" backward-delete-char "$__cl_funcs"

cl_set '()' 0
_autopair_backspace
check "cursor at 0: no forward delete" backward-delete-char "$__cl_funcs"
check "cursor at 0: buffer untouched" "()" "$__cl_buf"

#   ──────── history seed ────────

builtin history append 'cp /etc/hosts /tmp/backup/hosts.bak'
builtin history append 'echo foo foo bar'

#   ──────── _puffer_fish_expand_buck ────────

section _puffer_fish_expand_buck

cl_set 'echo '
_puffer_fish_expand_buck
check "plain context: inserts a literal \$" 'echo $' "$__cl_buf"

cl_set 'echo !'
_puffer_fish_expand_buck
check "!\$: the ! token is cleared" 'echo ' "$__cl_buf"
check "!\$: history-token-search-backward requested" history-token-search-backward "$__cl_funcs"

cl_set 'echo x'
set -g __cl_search 1 abc
_puffer_fish_expand_buck
check "search field active: \$ goes to the search field" 'abc$' "$__cl_search[2]"
check "search field active: buffer untouched" 'echo x' "$__cl_buf"

#   ──────── _puffer_fish_expand_star ────────

section _puffer_fish_expand_star

cl_set 'ls '
_puffer_fish_expand_star
check "plain context: inserts a literal *" 'ls *' "$__cl_buf"

cl_set 'printf !'
_puffer_fish_expand_star
check "!*: replaced by the previous command's arguments" 'printf foo foo bar' "$__cl_buf"

cl_set 'printf a!'
_puffer_fish_expand_star
check "a! is not the !* trigger" 'printf a!*' "$__cl_buf"

cl_set x
set -g __cl_search 1 ''
_puffer_fish_expand_star
check "search field active: * goes to the search field" '*' "$__cl_search[2]"

#   ──────── __insert_previous_path_head ────────

section __insert_previous_path_head

builtin history append 'cp /etc/hosts /tmp/backup/hosts.bak'
cl_set 'ls '
__insert_previous_path_head
check "inserts the dirname of the previous command's last argument" 'ls /tmp/backup' "$__cl_buf"

builtin history append 'vim notes.txt'
cl_set ''
__insert_previous_path_head
check "bare filename -> ." . "$__cl_buf"

builtin history append 'rm -- -weird/dir/file'
cl_set ''
__insert_previous_path_head
check "dash-leading path is not taken as a dirname option" -weird/dir "$__cl_buf"

#   ──────── __interactive_history_sub ────────

section __interactive_history_sub

builtin history append 'echo foo foo bar'
cl_set foo/baz
__interactive_history_sub
check "old/new replaces every occurrence in the last command" 'echo baz baz bar' "$__cl_buf"
check "repaint requested" repaint "$__cl_funcs"

cl_set ''
__interactive_history_sub
check "empty buffer: prepends sudo to the last command" 'sudo echo foo foo bar' "$__cl_buf"

builtin history append 'echo second'
cl_set foo/qux/2
__interactive_history_sub
check "old/new/N targets the Nth most recent command" 'echo qux qux bar' "$__cl_buf"

builtin history append 'echo f.o fxo'
cl_set 'f.o/X'
__interactive_history_sub
check "old is literal, not a regex" 'echo X fxo' "$__cl_buf"

cl_set 'nothing here'
__interactive_history_sub
check "non-matching buffer left alone" 'nothing here' "$__cl_buf"

cl_set foo/zz/999
__interactive_history_sub
check "out-of-range index leaves the buffer alone" foo/zz/999 "$__cl_buf"

#   ──────── _qalc_eval / _smart_execute ────────

mkdir -p $sandbox/bin $sandbox/empty
printf '%s\n' '#!/bin/sh' \
    'input=$(cat)' \
    'printf "%s\n" "$input" >>"$QALC_LOG"' \
    'printf "QALC[%s]\n" "$input"' >$sandbox/bin/qalc
chmod +x $sandbox/bin/qalc
set -gx QALC_LOG $sandbox/qalc.log
set -l saved_path $PATH

section _qalc_eval

set -gx PATH $sandbox/bin $saved_path
cl_set '2+2='
set -l out (_qalc_eval)
set -l code $status
check "with qalc: exit 0" 0 $code
check "buffer passed to qalc on stdin" '2+2=' (cat $QALC_LOG)
check "qalc output printed" 'QALC[2+2=]' "$out[-1]"
check "buffer cleared afterwards" '' "$__cl_buf"
check "repaint requested" repaint "$__cl_funcs"

command rm -f $QALC_LOG
cl_set '1; touch '$sandbox'/pwned ='
_qalc_eval >/dev/null
check "buffer is data, never evaluated by the shell" false (test -e $sandbox/pwned; and echo true; or echo false)
check "metacharacters reach qalc verbatim" '1; touch '$sandbox'/pwned =' (cat $QALC_LOG)

command rm -f $QALC_LOG
cl_set ''
_qalc_eval >/dev/null
check "empty buffer: qalc not run" false (test -e $QALC_LOG; and echo true; or echo false)

set -gx PATH $sandbox/empty
cl_set '3*3='
_qalc_eval >/dev/null
set code $status
check "without qalc: exit 1" 1 $code
check "without qalc: buffer untouched" '3*3=' "$__cl_buf"
check "without qalc: nothing requested of the editor" '' "$__cl_funcs"

section _smart_execute

set -gx PATH $sandbox/bin $saved_path
cl_set ''
_smart_execute
check "empty buffer -> execute" execute "$__cl_funcs"

cl_set 'ls -la'
_smart_execute
check "ordinary command -> execute" execute "$__cl_funcs"
check "ordinary command: buffer untouched" 'ls -la' "$__cl_buf"

cl_set 'a = b x'
_smart_execute
check "= not at the end -> execute" execute "$__cl_funcs"

command rm -f $QALC_LOG
cl_set '10/4='
set out (_smart_execute)
check "trailing = with qalc -> evaluated" 'QALC[10/4=]' "$out[-1]"
check "trailing = with qalc -> not executed" repaint "$__cl_funcs"

set -gx PATH $sandbox/empty
cl_set '10/4='
_smart_execute >/dev/null
check "trailing = without qalc -> falls back to execute" execute "$__cl_funcs"
check "fallback leaves the buffer for execution" '10/4=' "$__cl_buf"

set -gx PATH $saved_path
set -e QALC_LOG
functions -e commandline
report
