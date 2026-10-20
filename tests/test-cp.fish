#!/usr/bin/env fish
# Copyright (C) 2026 Rootiest
# SPDX-License-Identifier: AGPL-3.0-or-later
#
# MODE: isolated
#
# Coverage for the cp wrapper (functions/cp.fish) and its interaction with
# conf.d/tricks.fish. The wrapper owns cp's confirmation prompt: tricks.fish
# must not define a `cp` alias, because an alias is a function named cp and
# would stop functions/cp.fish from ever autoloading. Checked with a stub cp
# that logs its arguments, then with the real cp for the prompt.

source (realpath (dirname (status filename)))/lib.fish
set -p fish_function_path $repo_root/functions
source $repo_root/conf.d/__fish_config_op_registry.fish
set -gx NO_COLOR 1

set -g tmp (mktemp -d)
set -gx STUB_LOG $tmp/log

# A stub cp ahead of the real one on $PATH: logs its arguments, never copies.
command mkdir -p $tmp/stub
printf '%s\n' '#!/bin/sh' 'echo "$*" >>"$STUB_LOG"' >$tmp/stub/cp
chmod +x $tmp/stub/cp
set -l real_path $PATH

section "cp: tricks.fish leaves the wrapper in charge"

source $repo_root/conf.d/tricks.fish
check "tricks.fish defines no cp alias" "" (string match -r -- '^cp\s' (alias))
check "functions cp resolves to functions/cp.fish" $repo_root/functions/cp.fish (functions --details cp)

section "cp: -i while the guard is on"

set -gx PATH $tmp/stub $real_path
cp a b
check "plain copy gets -i" "-i a b" (cat $STUB_LOG)
command rm -f $STUB_LOG

cp -f a b
check "a caller's -f follows -i, so it wins" "-i -f a b" (cat $STUB_LOG)
command rm -f $STUB_LOG

section "cp: no -i when the guard is off"

for var in __fish_config_op_aliases __fish_config_op_aliases_filesystem
    set -g $var 0
    cp a b
    check "$var=0: bare cp, no -i" "a b" (cat $STUB_LOG)
    command rm -f $STUB_LOG
    set -e $var
end

set -g __fish_config_opinionated 0
cp a b
check "master switch off: bare cp, no -i" "a b" (cat $STUB_LOG)
command rm -f $STUB_LOG
set -e __fish_config_opinionated

section "cp: the real prompt"

set -gx PATH $real_path
set -l d $tmp/real
command mkdir -p $d
echo new >$d/src
echo old >$d/dst

echo n | cp $d/src $d/dst >/dev/null 2>&1
check "guard on: answering n keeps the destination" old (cat $d/dst)

echo y | cp $d/src $d/dst >/dev/null 2>&1
check "guard on: answering y overwrites" new (cat $d/dst)

echo new >$d/src
echo old >$d/dst
set -g __fish_config_op_aliases_filesystem 0
cp $d/src $d/dst >/dev/null 2>&1
check "guard off: overwrites without asking" new (cat $d/dst)
set -e __fish_config_op_aliases_filesystem

command rm -rf $tmp
report
