#!/usr/bin/env fish
# Copyright (C) 2026 Rootiest
# SPDX-License-Identifier: AGPL-3.0-or-later
#
# MODE: isolated
#
# Coverage for the directory listing on an empty Enter: __empty_enter_list
# writes `ls`, or `ls; git status -sb` inside a git work tree, into an empty
# command line. `commandline` only works at a live prompt, so it runs
# against a small model of it: a buffer and the pager/search mode.

source (realpath (dirname (status filename)))/lib.fish
set -p fish_function_path $repo_root/functions
set -gx NO_COLOR 1

set -g tmp (mktemp -d)
set -g saved_pwd $PWD

set -g __cl_buf ''
set -g __cl_mode ''

function commandline
    switch "$argv[1]"
        case --paging-mode
            test "$__cl_mode" = paging
        case --search-mode
            test "$__cl_mode" = search
        case -r
            set -g __cl_buf $argv[-1]
        case '*'
            printf '%s\n' $__cl_buf
    end
end

# press <buffer> [mode]
function press
    set -g __cl_buf $argv[1]
    set -g __cl_mode "$argv[2]"
    __empty_enter_list
end

mkdir -p $tmp/plain $tmp/repo/sub
command git -C $tmp/repo init -q
command git init -q --bare $tmp/bare.git

#   ──────── Outside a repo ────────

section "outside a git repo"

cd $tmp/plain
set -e __fish_empty_enter_git
press ''
check "empty line becomes ls" ls "$__cl_buf"
press ' '
check "a lone space is left alone" ' ' "$__cl_buf"
press 'echo hi'
check "a command is left alone" 'echo hi' "$__cl_buf"
press '' paging
check "pager open: untouched" '' "$__cl_buf"
press '' search
check "history search: untouched" '' "$__cl_buf"
cd $tmp/bare.git
press ''
check "inside a bare repo: plain ls" ls "$__cl_buf"

#   ──────── Inside a repo ────────

section "inside a git work tree"

cd $tmp/repo/sub
press ''
check "empty line adds git status" 'ls; git status -sb' "$__cl_buf"
cd $tmp/repo/.git
press ''
check "inside .git: plain ls" ls "$__cl_buf"
cd $tmp/repo

for val in off 0 false No
    set -g __fish_empty_enter_git $val
    press ''
    check "__fish_empty_enter_git=$val: plain ls" ls "$__cl_buf"
end
for val in on 1 yes banana
    set -g __fish_empty_enter_git $val
    press ''
    check "__fish_empty_enter_git=$val: git status kept" 'ls; git status -sb' "$__cl_buf"
end
set -e __fish_empty_enter_git

set -l saved_path $PATH
mkdir -p $tmp/nobin
set PATH $tmp/nobin
press ''
set PATH $saved_path
check "git not installed: plain ls" ls "$__cl_buf"

cd $saved_pwd
command rm -rf $tmp
report
