#!/usr/bin/env fish
# Copyright (C) 2026 Rootiest
# SPDX-License-Identifier: AGPL-3.0-or-later
#
# Coverage for mkrep: directory creation + cd + git init, plus its flag
# matrix (--clean/--strict interaction, --no-* precedence, remote linking
# and remote creation via a user command template).
#
# Runs isolated (no `# MODE:` marker). mkrep does real filesystem
# mutations and cds, so every case works inside its own mktemp -d sandbox
# and restores $PWD afterward -- this suite runs autoloaded straight in
# the driver's own process (like test-guards.fish), so a stray cd or a
# leftover sandbox would leak into later cases/suites.

source (realpath (dirname (status filename)))/lib.fish
set -p fish_function_path $repo_root/functions

function _mkrep_sandbox
    set -l tmp (mktemp -d)
    # Resolve symlinks (e.g. macOS/NixOS /tmp) so path comparisons against
    # mkrep's own `path resolve` output agree.
    path resolve $tmp
end

section "mkrep: defaults"

set -l start $PWD
set -l base (_mkrep_sandbox)
set -l target $base/repo
mkrep $target >/dev/null
set -l code $status
check "default run exits 0" 0 $code
check "directory created" true (test -d $target; and echo true; or echo false)
check "cwd entered" $target (path resolve $PWD)
check "git repo initialized" true (test -d $target/.git; and echo true; or echo false)
cd $start
rm -rf $base

section "mkrep: --no-cd"

set -l base (_mkrep_sandbox)
set -l target $base/repo
mkrep --no-cd $target >/dev/null
check "--no-cd exits 0" 0 $status
check "--no-cd leaves cwd alone" $start (path resolve $PWD)
check "--no-cd still creates the directory" true (test -d $target; and echo true; or echo false)
check "--no-cd still git inits" true (test -d $target/.git; and echo true; or echo false)
rm -rf $base

section "mkrep: --no-git"

set -l base (_mkrep_sandbox)
set -l target $base/repo
mkrep --no-git $target >/dev/null
check "--no-git exits 0" 0 $status
check "--no-git skips git init" false (test -d $target/.git; and echo true; or echo false)
cd $start
rm -rf $base

section "mkrep: --no-mkdir"

set -l base (_mkrep_sandbox)
set -l target $base/does-not-exist
mkrep --no-mkdir $target >/dev/null 2>/tmp/mkrep-test-err
check "--no-mkdir on missing dir exits 1" 1 $status
check "--no-mkdir does not create the directory" false (test -d $target; and echo true; or echo false)
rm -f /tmp/mkrep-test-err
rm -rf $base

section "mkrep: --strict"

set -l base (_mkrep_sandbox)
set -l target $base/repo
mkdir -p $target
echo sentinel >$target/keep.txt
mkrep --strict $target >/dev/null 2>/tmp/mkrep-test-err
check "--strict on existing dir exits 1" 1 $status
check "--strict leaves the directory untouched" true (test -f $target/keep.txt; and echo true; or echo false)
check "--strict never git inits" false (test -d $target/.git; and echo true; or echo false)
rm -f /tmp/mkrep-test-err
cd $start
rm -rf $base

section "mkrep: --clean"

set -l base (_mkrep_sandbox)
set -l target $base/repo
mkdir -p $target
echo sentinel >$target/keep.txt
mkrep --clean $target >/dev/null
check "--clean exits 0" 0 $status
check "--clean removes prior contents" false (test -f $target/keep.txt; and echo true; or echo false)
check "--clean still leaves a fresh git repo" true (test -d $target/.git; and echo true; or echo false)
cd $start
rm -rf $base

section "mkrep: --clean --strict compose"

set -l base (_mkrep_sandbox)
set -l target $base/repo
mkdir -p $target
echo sentinel >$target/keep.txt
mkrep --clean --strict $target >/dev/null
check "--clean --strict together succeeds" 0 $status
cd $start
rm -rf $base

section "mkrep: negative flag wins over positive"

set -l base (_mkrep_sandbox)
set -l target $base/repo
mkdir -p $target
echo sentinel >$target/keep.txt
mkrep --clean --no-clean $target >/dev/null
check "--clean --no-clean: no-clean wins, contents survive" true (test -f $target/keep.txt; and echo true; or echo false)
cd $start
rm -rf $base

set -l base (_mkrep_sandbox)
set -l target $base/repo
mkrep --cd --no-cd $target >/dev/null
check "--cd --no-cd: no-cd wins, cwd unchanged" $start (path resolve $PWD)
rm -rf $base

section "mkrep: -s/--silent"

set -l base (_mkrep_sandbox)
set -l target $base/repo
set -l out (mkrep -s $target)
check "-s exits 0" 0 $status
check "-s prints nothing" 0 (count $out)
cd $start
rm -rf $base

section "mkrep: --remote (link only)"

set -l base (_mkrep_sandbox)
set -l target $base/repo
mkrep --remote https://example.invalid/me/repo.git $target >/dev/null
check "--remote exits 0" 0 $status
set -l url (git -C $target remote get-url origin)
check "--remote links origin to the given url" https://example.invalid/me/repo.git $url
cd $start
rm -rf $base

section "mkrep: --remote and --new-remote are exclusive"

set -l base (_mkrep_sandbox)
set -l target $base/repo
mkrep --remote https://example.invalid/x.git --new-remote $target >/dev/null 2>/tmp/mkrep-test-err
check "--remote + --new-remote exits 1" 1 $status
check "conflicting remote flags create nothing" false (test -d $target; and echo true; or echo false)
rm -f /tmp/mkrep-test-err
rm -rf $base

section "mkrep: --new-remote requires --git"

set -l base (_mkrep_sandbox)
set -l target $base/repo
mkrep --no-git --new-remote $target >/dev/null 2>/tmp/mkrep-test-err
check "--no-git + --new-remote exits 1" 1 $status
check "rejected combo creates nothing" false (test -d $target; and echo true; or echo false)
rm -f /tmp/mkrep-test-err
rm -rf $base

section "mkrep: --new-remote runs a command template"

set -l base (_mkrep_sandbox)
set -l target $base/repo
mkrep --new-remote='echo {name}/{user} >created.txt' --name demo-repo $target >/dev/null
check "--new-remote exits 0" 0 $status
check "template command ran in the new repo dir" "demo-repo/$USER" (cat $target/created.txt)
cd $start
rm -rf $base

section "mkrep: --new-remote falls back to \$MKREP_REMOTE_CMD"

set -l base (_mkrep_sandbox)
set -l target $base/repo
set -lx MKREP_REMOTE_CMD 'echo {name} >created.txt'
mkrep --new-remote $target >/dev/null
check "env fallback exits 0" 0 $status
check "env fallback template ran" repo (cat $target/created.txt)
cd $start
rm -rf $base

section "mkrep: --help"

set -l base (_mkrep_sandbox)
set -l out (mkrep --help)
check "--help exits 0" 0 $status
check "--help prints usage" true (string match -q -- '*Usage:*' $out; and echo true; or echo false)
check "--help creates nothing" false (test -d $base/repo; and echo true; or echo false)
rm -rf $base

cd $start
report
