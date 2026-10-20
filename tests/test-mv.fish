#!/usr/bin/env fish
# Copyright (C) 2026 Rootiest
# SPDX-License-Identifier: AGPL-3.0-or-later
#
# MODE: isolated
#
# Coverage for the mv wrapper (functions/mv.fish) and its interaction with
# conf.d/tricks.fish. The wrapper owns mv's confirmation prompt: tricks.fish
# must not define an `mv` alias, because an alias is a function named mv and
# would stop functions/mv.fish (nested-directory auto-collapse) from ever
# autoloading. Checked with a stub mv that logs its arguments, then with the
# real mv for the prompt and the collapse.

source (realpath (dirname (status filename)))/lib.fish
set -p fish_function_path $repo_root/functions
source $repo_root/conf.d/__fish_config_op_registry.fish
set -gx NO_COLOR 1

set -g tmp (mktemp -d)
set -gx STUB_LOG $tmp/log

# A stub mv ahead of the real one on $PATH: logs its arguments, never moves.
command mkdir -p $tmp/stub
printf '%s\n' '#!/bin/sh' 'echo "$*" >>"$STUB_LOG"' >$tmp/stub/mv
chmod +x $tmp/stub/mv
set -l real_path $PATH

section "mv: tricks.fish leaves the wrapper in charge"

source $repo_root/conf.d/tricks.fish
check "tricks.fish defines no mv alias" "" (string match -r -- '^mv\s' (alias))
check "functions mv resolves to functions/mv.fish" $repo_root/functions/mv.fish (functions --details mv)

section "mv: -i while the guard is on"

set -gx PATH $tmp/stub $real_path
mv a b
check "plain move gets -i" "-i a b" (cat $STUB_LOG)
command rm -f $STUB_LOG

mv -f a b
check "a caller's -f follows -i, so it wins" "-i -f a b" (cat $STUB_LOG)
command rm -f $STUB_LOG

section "mv: no -i when the guard is off"

for var in __fish_config_op_aliases __fish_config_op_aliases_filesystem
    set -g $var 0
    mv a b
    check "$var=0: bare mv, no -i" "a b" (cat $STUB_LOG)
    command rm -f $STUB_LOG
    set -e $var
end

set -g __fish_config_opinionated 0
mv a b
check "master switch off: bare mv, no -i" "a b" (cat $STUB_LOG)
command rm -f $STUB_LOG
set -e __fish_config_opinionated

section "mv: the real prompt"

set -gx PATH $real_path
set -l d $tmp/real
command mkdir -p $d
echo new >$d/src
echo old >$d/dst

echo n | mv $d/src $d/dst >/dev/null 2>&1
check "guard on: answering n keeps the destination" old (cat $d/dst)

echo y | mv $d/src $d/dst >/dev/null 2>&1
check "guard on: answering y overwrites" new (cat $d/dst)

echo new >$d/src
echo old >$d/dst
set -g __fish_config_op_aliases_filesystem 0
mv $d/src $d/dst >/dev/null 2>&1
check "guard off: overwrites without asking" new (cat $d/dst)
set -e __fish_config_op_aliases_filesystem

section "mv: nested-directory auto-collapse"

set -l n $tmp/nest/themes
command mkdir -p $n/themes
echo x >$n/themes/a.txt
echo y >$n/themes/.hidden
mv $n/themes $n >/dev/null 2>&1
check "collapse exits 0" 0 $status
check "contents moved up one level" "x y" (cat $n/a.txt $n/.hidden | string join ' ')
check "inner shell removed" false (test -e $n/themes; and echo true; or echo false)

command rm -rf $tmp
report
