#!/usr/bin/env fish
# Copyright (C) 2026 Rootiest
# SPDX-License-Identifier: AGPL-3.0-or-later
#
# Coverage for small shared helpers the rest of the config leans on:
# __fish_help_requested and __fish_no_args (the help/usage convention),
# _fish_source_scoped (contains a sourced file's `return`),
# __fish_real_command (skips our own wrapper shims on $PATH),
# __fish_user_dots_link (the C2 user-dots convenience symlink) and
# __fish_config_op_registry_rebuild (regenerates the component registry).
#
# Runs isolated (no `# MODE:` marker): the last two write files under
# $__fish_config_dir, which fish makes read-only and derives from
# $XDG_CONFIG_HOME at startup. So the suite first re-executes itself in a
# child `fish --no-config` whose XDG_CONFIG_HOME is a fresh mktemp -d,
# whatever the caller's was: run by hand or by run-tests.fish, every write
# lands in that sandbox. The real ~/.config/fish/user-dots link and the
# committed registry are never touched; a check below proves the former.

if not set -q __core_helpers_child
    set -l x (mktemp -d)
    env __core_helpers_child=1 XDG_CONFIG_HOME=$x/cfg fish --no-config (status filename)
    set -l rc $status
    rm -rf $x
    exit $rc
end

source (realpath (dirname (status filename)))/lib.fish
set -p fish_function_path $repo_root/functions

set -g sandbox (path resolve (mktemp -d))
set -g cfg $__fish_config_dir
mkdir -p $cfg

function yes_no
    if $argv
        echo true
    else
        echo false
    end
end

#   ─────────────────────── __fish_help_requested ──────────────────────

section __fish_help_requested

__fish_help_requested -h
check "-h -> 0" 0 $status
__fish_help_requested --help
check "--help -> 0" 0 $status
__fish_help_requested sub --flag x --help
check "--help after other args -> 0" 0 $status
__fish_help_requested
check "no args -> 1" 1 $status
__fish_help_requested sub arg
check "no help flag -> 1" 1 $status
__fish_help_requested -- -h
check "-h after -- -> 1" 1 $status
__fish_help_requested sub -- --help
check "--help after -- -> 1" 1 $status
__fish_help_requested -h --
check "-h before -- -> 0" 0 $status
for near in help HELP -help --HELP -H --help=1 ' -h'
    __fish_help_requested $near
    check "'$near' is not a help flag" 1 $status
end

#   ─────────────────────────── __fish_no_args ─────────────────────────

section __fish_no_args

set -l err (__fish_no_args myfn 2>&1)
check "no extra args -> 0" 0 $status
check "no extra args: silent" "" "$err"
set -l out (__fish_no_args myfn --dry-run 2>/dev/null)
check "an arg -> 2" 2 $status
check "an arg: nothing on stdout" "" "$out"
set -l err (__fish_no_args myfn --dry-run extra 2>&1 >/dev/null | string collect)
check "error names the function and first arg" true (yes_no string match -q "*myfn: unexpected argument '--dry-run'*" -- "$err")
check "error points at --help" true (yes_no string match -q '*myfn --help*' -- "$err")
__fish_no_args myfn '' 2>/dev/null
check "an empty-string arg still counts -> 2" 2 $status

#   ───────────────────────── _fish_source_scoped ──────────────────────

section _fish_source_scoped

_fish_source_scoped $sandbox/missing.fish
check "missing file -> 0" 0 $status

printf '%s\n' 'set -g __probe_sourced yes' >$sandbox/ok.fish
_fish_source_scoped $sandbox/ok.fish
check "existing file -> 0" 0 $status
check "file was sourced (globals land)" yes "$__probe_sourced"

printf '%s\n' 'set -g __probe_early 1' 'return 3' 'set -g __probe_after 1' >$sandbox/early.fish
function __probe_caller
    _fish_source_scoped $sandbox/early.fish
    set -g __probe_caller_status $status
    set -g __probe_caller_continued yes
end
__probe_caller
check "sourced file's return status propagates" 3 "$__probe_caller_status"
check "return stopped the sourced file" false (set -q __probe_after; and echo true; or echo false)
check "return did not unwind the caller" yes "$__probe_caller_continued"

printf '%s\n' false >$sandbox/fails.fish
_fish_source_scoped $sandbox/fails.fish
check "last-command failure propagates" 1 $status

mkdir -p "$sandbox/dir with space"
printf '%s\n' 'set -g __probe_space ok' >"$sandbox/dir with space/f.fish"
_fish_source_scoped "$sandbox/dir with space/f.fish"
check "path with spaces is sourced" ok "$__probe_space"

_fish_source_scoped $sandbox
check "a directory is not sourced -> 0" 0 $status

_fish_source_scoped ''
check "empty-string path -> 2, nothing sourced" 2 $status

# No argument at all: `test -f $file` once collapsed to `test -f` (true)
# and the bare `source` then executed stdin (#310). Feed stdin a probe so
# a regression shows up as the global landing, not just a wrong status.
set -e __probe_stdin
echo 'set -g __probe_stdin sourced' | _fish_source_scoped
check "no argument -> 2" 2 $pipestatus[2]
check "no argument does not source stdin" false (set -q __probe_stdin; and echo true; or echo false)

#   ───────────────────────── __fish_real_command ──────────────────────

section __fish_real_command

# The helper shells out to grep, so every narrowed $PATH below also carries
# a directory holding only a grep symlink.
set -l grepbin $sandbox/grepbin
mkdir -p $grepbin
ln -s (command -s grep) $grepbin/grep

set -l rc_dirs $sandbox/rc-wrap $sandbox/rc-other $sandbox/rc-real $sandbox/rc-bin
mkdir -p $rc_dirs
printf '%s\n' '#!/bin/sh' '# paru-wrapper-version: 3' 'exec paru "$@"' >$sandbox/rc-wrap/paru
# A different tool's marker must not make this one count as our wrapper.
printf '%s\n' '#!/bin/sh' '# yay-wrapper-version: 3' 'echo real' >$sandbox/rc-other/paru
printf '%s\n' '#!/bin/sh' 'echo real' >$sandbox/rc-real/paru
cp (command -s true) $sandbox/rc-bin/paru
chmod +x $sandbox/rc-*/paru

begin
    set -lx PATH $sandbox/rc-wrap $sandbox/rc-real $grepbin
    set -g __probe_out (__fish_real_command paru)
    set -g __probe_rc $status
end
check "skips our wrapper, returns the next match" $sandbox/rc-real/paru "$__probe_out"
check "found -> 0" 0 $__probe_rc

begin
    set -lx PATH $sandbox/rc-wrap $sandbox/rc-other $sandbox/rc-real $grepbin
    set -g __probe_out (__fish_real_command paru)
end
check "another tool's marker does not count" $sandbox/rc-other/paru "$__probe_out"

begin
    set -lx PATH $sandbox/rc-wrap $sandbox/rc-bin $grepbin
    set -g __probe_out (__fish_real_command paru)
    set -g __probe_rc $status
end
check "a real ELF binary is returned" $sandbox/rc-bin/paru "$__probe_out"
check "binary found -> 0" 0 $__probe_rc

begin
    set -lx PATH $sandbox/rc-real $sandbox/rc-wrap $grepbin
    set -g __probe_out (__fish_real_command paru)
end
check "first non-wrapper wins when it comes first" $sandbox/rc-real/paru "$__probe_out"

begin
    set -lx PATH $sandbox/rc-wrap $grepbin
    set -g __probe_out (__fish_real_command paru)
    set -g __probe_rc $status
end
check "only our wrapper on PATH -> 1" 1 $__probe_rc
check "only our wrapper: prints nothing" "" "$__probe_out"

begin
    set -lx PATH $sandbox/rc-wrap $grepbin
    set -g __probe_out (__fish_real_command definitely-not-a-cmd)
    set -g __probe_rc $status
end
check "not on PATH at all -> 1" 1 $__probe_rc
check "exactly one line when several qualify" 1 (begin; set -lx PATH $sandbox/rc-real $sandbox/rc-bin $grepbin; count (__fish_real_command paru); end)

#   ──────────────────────── __fish_user_dots_link ─────────────────────

section __fish_user_dots_link

# The guard needs the committed registry to know this is a C2 component.
source $repo_root/conf.d/__fish_config_op_registry.fish

set -l real_link_before (readlink $HOME/.config/fish/user-dots 2>/dev/null)

set -l link $cfg/user-dots
mkdir -p $sandbox/dots-a $sandbox/dots-b
set -e __fish_user_dots_symlink
set -e __fish_config_op_autoexec
set -e __fish_config_opinionated

set -g __fish_user_dots_path $sandbox/dots-a
__fish_user_dots_link
check "default: exits 0" 0 $status
check "default: creates the link" $sandbox/dots-a (readlink $link)

set -g __fish_user_dots_path $sandbox/dots-b
__fish_user_dots_link
check "target changed: exits 0" 0 $status
check "target changed: link repointed" $sandbox/dots-b (readlink $link)
# The link must be replaced, not followed: ln -s into an existing directory
# link would drop a nested link inside the old target instead.
check "repoint left nothing inside the old target" "" (ls -A $sandbox/dots-a | string collect)

__fish_user_dots_link
check "already correct: exits 0" 0 $status
check "already correct: link unchanged" $sandbox/dots-b (readlink $link)
check "already correct: no nested link in target" "" (ls -A $sandbox/dots-b | string collect)

set -g __fish_user_dots_symlink 0
__fish_user_dots_link
check "opt-out: exits 0" 0 $status
check "opt-out: link removed" false (yes_no test -L $link)
check "opt-out: target dir untouched" true (yes_no test -d $sandbox/dots-b)

__fish_user_dots_link
check "opt-out with nothing to remove: exits 0" 0 $status

for v in false no off OFF N
    set -g __fish_user_dots_symlink $v
    ln -s $sandbox/dots-b $link
    __fish_user_dots_link
    check "opt-out '$v' removes the link" false (yes_no test -L $link)
end

# Opt-out cleanup is honored even with C2 disabled.
set -g __fish_config_op_autoexec 0
set -g __fish_user_dots_symlink 0
ln -s $sandbox/dots-b $link
__fish_user_dots_link
check "opt-out, C2 off: link still removed" false (yes_no test -L $link)

# Creation is a C2 side effect: C2 off means no link.
set -e __fish_user_dots_symlink
__fish_user_dots_link
check "C2 off: exits 0" 0 $status
check "C2 off: no link created" false (yes_no test -e $link -o -L $link)
set -e __fish_config_op_autoexec

set -g __fish_config_opinionated 0
__fish_user_dots_link
check "master switch off: no link created" false (yes_no test -e $link -o -L $link)
set -e __fish_config_opinionated

set -g __fish_user_dots_symlink 1
__fish_user_dots_link
check "explicit truthy toggle: creates the link" $sandbox/dots-b (readlink $link)
rm -f $link
set -e __fish_user_dots_symlink

# Never manages anything but a symlink.
echo precious >$link
__fish_user_dots_link
check "real file at link path: exits 0" 0 $status
check "real file at link path: untouched" precious (cat $link)
set -g __fish_user_dots_symlink 0
__fish_user_dots_link
check "opt-out never removes a real file" precious (cat $link)
rm -f $link
set -e __fish_user_dots_symlink

mkdir $link
echo keep >$link/keep
__fish_user_dots_link
check "real dir at link path: untouched" keep (cat $link/keep)
check "real dir at link path: no link dropped inside" false (yes_no test -L $link/dots-b)
set -g __fish_user_dots_symlink 0
__fish_user_dots_link
check "opt-out never removes a real dir" true (yes_no test -d $link)
rm -rf $link
set -e __fish_user_dots_symlink

# Missing target: nothing to link to.
set -g __fish_user_dots_path $sandbox/does-not-exist
__fish_user_dots_link
check "missing target: exits 0" 0 $status
check "missing target: no link created" false (yes_no test -e $link -o -L $link)

# Unset path falls back to $XDG_CONFIG_HOME/.user-dots/fish.
set -e __fish_user_dots_path
mkdir -p $sandbox/xdg/.user-dots/fish
begin
    set -lx XDG_CONFIG_HOME $sandbox/xdg
    __fish_user_dots_link
end
check "unset path: falls back under XDG_CONFIG_HOME" $sandbox/xdg/.user-dots/fish (readlink $link)

check "real ~/.config/fish/user-dots untouched" "$real_link_before" (readlink $HOME/.config/fish/user-dots 2>/dev/null)

#   ───────────────── __fish_config_op_registry_rebuild ────────────────

section __fish_config_op_registry_rebuild

mkdir -p $cfg/conf.d $cfg/docs $sandbox/regbin $sandbox/regempty

# A stub python3: logs its argv, writes a registry that sets a probe
# global, and exits $STUB_RC.
printf '%s\n' '#!/bin/sh' \
    'printf "%s\n" "$@" >"$STUB_LOG"' \
    '[ "${STUB_RC:-0}" = 0 ] || exit "$STUB_RC"' \
    'printf "set -g __probe_registry rebuilt\n" >"$REG_OUT"' >$sandbox/regbin/python3
chmod +x $sandbox/regbin/python3
set -l reg $cfg/conf.d/__fish_config_op_registry.fish

set -e __probe_registry
begin
    set -lx PATH $sandbox/regempty
    set -g __probe_err (__fish_config_op_registry_rebuild 2>&1)
    set -g __probe_rc $status
end
check "no python3 -> 1" 1 $__probe_rc
check "no python3: says so" true (yes_no string match -q '*python3 not found*' -- "$__probe_err")
check "no python3: registry not written" false (yes_no test -e $reg)

printf '%s\n' 'set -g __probe_registry stale' >$reg
begin
    set -lx PATH $sandbox/regbin
    set -lx STUB_LOG $sandbox/reg.log
    set -lx REG_OUT $reg
    set -lx STUB_RC 1
    __fish_config_op_registry_rebuild
    set -g __probe_rc $status
end
check "generator fails -> 1" 1 $__probe_rc
check "generator fails: stale registry not re-sourced" false (set -q __probe_registry; and echo true; or echo false)

begin
    set -lx PATH $sandbox/regbin
    set -lx STUB_LOG $sandbox/reg.log
    set -lx REG_OUT $reg
    __fish_config_op_registry_rebuild
    set -g __probe_rc $status
end
check "generator succeeds -> 0" 0 $__probe_rc
check "runs the generator under \$__fish_config_dir" $cfg/docs/generate_component_registry.py (cat $sandbox/reg.log)
check "re-sources the fresh registry into the session" rebuilt "$__probe_registry"

# End to end with the real generator, on a sandbox copy of the tree so the
# committed registry is never rewritten. Needs python3 + PyYAML (manualtools).
if command -q python3; and command python3 -c 'import yaml' 2>/dev/null
    set -l copy $cfg
    rm -rf $copy/conf.d $copy/docs
    mkdir -p $copy/docs
    cp -r $repo_root/functions $repo_root/conf.d $copy/
    cp $repo_root/config.fish $copy/
    cp $repo_root/docs/generate_component_registry.py $repo_root/docs/manualtools.py $copy/docs/
    rm -f $copy/conf.d/__fish_config_op_registry.fish
    set -e __fish_config_op_registry_keys
    __fish_config_op_registry_rebuild >/dev/null 2>&1
    check "real generator: exits 0" 0 $status
    check "real generator: registry written" true (yes_no test -f $copy/conf.d/__fish_config_op_registry.fish)
    check "real generator: keys loaded into the session" true (yes_no contains -- "__fish_user_dots_link:" $__fish_config_op_registry_keys)
    check "real generator: output matches the committed registry" (string collect <$repo_root/conf.d/__fish_config_op_registry.fish) (string collect <$copy/conf.d/__fish_config_op_registry.fish)
else
    echo "  SKIP  real generator run (python3 with PyYAML not available)"
end

rm -rf $sandbox
report
