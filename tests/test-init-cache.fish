#!/usr/bin/env fish
# Copyright (C) 2026 Rootiest
# SPDX-License-Identifier: AGPL-3.0-or-later
#
# MODE: isolated
#
# Issue #237: __fish_init_cache, the on-disk cache for generated tool init
# scripts (`fzf --fish`, `direnv hook fish`). The properties that matter are
# the negative ones, so most cases are about NOT serving a stale entry:
#
#   * cold cache: generates, sources and stores
#   * hit: the generator is not run again, and the same init is sourced
#   * invalidation: a changed binary mtime, another binary earlier on PATH,
#     a re-pointed symlink and a changed command line each regenerate
#   * fallback: opt-out, missing binary, failing or silent generator, broken
#     or truncated cache file and an unwritable cache dir all end in a
#     correct (live) result and never a broken or half-written entry
#   * config.fish wiring: the real fzf and direnv blocks, cut out of the
#     file, behave the same with a hot cache, a cold cache and an old fzf
#
# Generators are stub scripts that count their invocations, so "was not run"
# is an assertion rather than an inference. Everything lives under a
# throwaway HOME/XDG_CACHE_HOME.

source (realpath (dirname (status filename)))/lib.fish
set -p fish_function_path $repo_root/functions

set -g sandbox (mktemp -d)
set -gx HOME $sandbox/home
set -gx XDG_CACHE_HOME $sandbox/cache
command mkdir -p $HOME $sandbox/bin $sandbox/bin2
set -g cache_dir $XDG_CACHE_HOME/fish-config/init
set -g runlog $sandbox/runs
set -g __saved_path $PATH
set -gx PATH $sandbox/bin $PATH

function yesno
    if $argv
        echo true
    else
        echo false
    end
end

# A generator stub at $argv[1] (a path). Each run appends a line to $runlog
# and prints a script setting __ic_marker to $argv[2]. $argv[3], when given,
# is a mode: fail (exit 3), silent (no output, exit 0), garbage (invalid fish,
# exit 0).
function make_gen --argument-names path marker mode
    printf '%s\n' '#!/bin/sh' "echo run >>$runlog" >$path
    switch "$mode"
        case fail
            echo 'exit 3' >>$path
        case silent
            echo 'exit 0' >>$path
        case garbage
            echo 'echo "if if if ((("' >>$path
        case '*'
            echo "echo 'set -g __ic_marker $marker'" >>$path
    end
    command chmod +x $path
end

function runs
    test -f $runlog; and count (string match -r . <$runlog); or echo 0
end

function reset_state
    set -e __ic_marker
    command rm -f $runlog
    command rm -rf $XDG_CACHE_HOME
    set -e __fish_config_init_cache
end

set -g gen $sandbox/bin/icgen

section "init-cache: cold cache"

reset_state
make_gen $gen v1
__fish_init_cache ic icgen --init
check "returns 0" 0 $status
check "generated init was sourced" v1 "$__ic_marker"
check "generator ran once" 1 (runs)
check "entry stored" true (yesno test -f $cache_dir/ic.fish)
check "entry is a comment header, the init, then the end marker" \
    "# fish-config init-cache v1|set -g __ic_marker v1|# fish-config init-cache end" \
    (string join '|' (string match -r '^# fish-config init-cache v1|^set .*|^# fish-config init-cache end$' <$cache_dir/ic.fish | string replace -r '^(# fish-config init-cache v1) .*' '$1 '))
check "cache dir is private" 700 (stat -c %a $cache_dir)
check "no temp file left behind" 1 (count $cache_dir/*)

section "init-cache: hit"

set -e __ic_marker
__fish_init_cache ic icgen --init
check "returns 0" 0 $status
check "cached init was sourced" v1 "$__ic_marker"
check "generator NOT run again" 1 (runs)
set -e __ic_marker
__fish_init_cache ic icgen --init
check "second hit: still not run" 1 (runs)
check "second hit: still sourced" v1 "$__ic_marker"

section "init-cache: invalidation"

# A rebuilt or upgraded binary: new content and a new mtime.
make_gen $gen v2
command touch -d '2031-01-01 00:00:00' $gen
set -e __ic_marker
__fish_init_cache ic icgen --init
check "changed mtime: regenerated" 2 (runs)
check "changed mtime: new init sourced" v2 "$__ic_marker"
set -e __ic_marker
__fish_init_cache ic icgen --init
check "changed mtime: new entry then hits" 2 (runs)
check "changed mtime: and serves the new init" v2 "$__ic_marker"

# Touch alone is a different mtime, hence a different key: conservative, a
# spurious regeneration is correct, a stale hit is not.
command touch -d '2032-01-01 00:00:00' $gen
__fish_init_cache ic icgen --init
check "mtime-only change: regenerated" 3 (runs)

# Another binary of the same name earlier on PATH.
make_gen $sandbox/bin2/icgen other
command touch -d '2031-01-01 00:00:00' $sandbox/bin2/icgen
set -e __ic_marker
begin
    set -lx PATH $sandbox/bin2 $PATH
    __fish_init_cache ic icgen --init
end
check "other binary on PATH: regenerated" 4 (runs)
check "other binary on PATH: its init sourced" other "$__ic_marker"
set -e __ic_marker
__fish_init_cache ic icgen --init
check "back to the first binary: regenerated again" 5 (runs)
check "back to the first binary: its init sourced" v2 "$__ic_marker"

# A different command line is a different output.
set -e __ic_marker
__fish_init_cache ic icgen --other-flag
check "different arguments: regenerated" 6 (runs)

# A symlink re-pointed at another file (same mtime on the link target by
# construction): the resolved path is in the key.
make_gen $sandbox/real-a a
make_gen $sandbox/real-b b
command touch -d '2030-01-01 00:00:00' $sandbox/real-a $sandbox/real-b
command ln -s $sandbox/real-a $sandbox/bin/iclink
set -e __ic_marker
__fish_init_cache lk iclink
check "symlink: first target sourced" a "$__ic_marker"
set -l before (runs)
command ln -sfn $sandbox/real-b $sandbox/bin/iclink
set -e __ic_marker
__fish_init_cache lk iclink
check "symlink re-pointed: regenerated" (math $before + 1) (runs)
check "symlink re-pointed: new target's init sourced" b "$__ic_marker"

section "init-cache: documented limit"

# The key is path + mtime (one-second resolution) + command line + fish
# version. Content swapped under an identical mtime is NOT detected; this
# pins that so the claim in the docs stays honest. A package manager
# replacing a binary always changes its mtime.
reset_state
make_gen $gen same
command touch -d '2029-01-01 00:00:00' $gen
__fish_init_cache ic icgen --init
make_gen $gen swapped
command touch -d '2029-01-01 00:00:00' $gen
set -e __ic_marker
__fish_init_cache ic icgen --init
check "same path+mtime, new content: served from cache (limit)" same "$__ic_marker"
__fish_init_cache --clear ic
set -e __ic_marker
__fish_init_cache ic icgen --init
check "--clear <name> drops it; fresh output follows" swapped "$__ic_marker"

section "init-cache: broken cache files fall back to a live run"

reset_state
make_gen $gen good
command touch -d '2028-01-01 00:00:00' $gen
__fish_init_cache ic icgen --init
set -l good (string collect <$cache_dir/ic.fish)

# truncated: header intact, end marker (and half the body) gone
printf '%s\n' (string split \n -- $good)[1] 'set -g __ic_marker POISON' >$cache_dir/ic.fish
set -e __ic_marker
__fish_init_cache ic icgen --init
check "truncated entry: not trusted" good "$__ic_marker"
check "truncated entry: regenerated" 2 (runs)
check "truncated entry: rewritten whole" true (yesno string match -q '*init-cache end' (string collect <$cache_dir/ic.fish))

# garbage header
printf '%s\n' '# nonsense' 'set -g __ic_marker POISON' '# fish-config init-cache end' >$cache_dir/ic.fish
set -e __ic_marker
__fish_init_cache ic icgen --init
check "foreign header: not trusted" good "$__ic_marker"

# a key from another fish version / format revision
printf '%s\n' '# fish-config init-cache v0 x|y' 'set -g __ic_marker POISON' '# fish-config init-cache end' >$cache_dir/ic.fish
set -e __ic_marker
__fish_init_cache ic icgen --init
check "old format revision: not trusted" good "$__ic_marker"

# empty file
: >$cache_dir/ic.fish
set -e __ic_marker
__fish_init_cache ic icgen --init
check "empty entry: not trusted" good "$__ic_marker"

# a directory where the file should be
command rm -f $cache_dir/ic.fish
command mkdir $cache_dir/ic.fish
set -e __ic_marker
__fish_init_cache ic icgen --init
check "directory in the way: still sources the live output" good "$__ic_marker"
check "directory in the way: exits 0" 0 $status
command rmdir $cache_dir/ic.fish
check "directory in the way: no temp file left" 0 (count (path filter $cache_dir/ic.fish.*))

section "init-cache: generator problems are never cached"

reset_state
make_gen $gen x fail
__fish_init_cache ic icgen --init 2>/dev/null
check "failing generator: returns 1 (caller runs it live)" 1 $status
check "failing generator: nothing sourced" "" "$__ic_marker"
check "failing generator: nothing stored" false (yesno test -e $cache_dir/ic.fish)

make_gen $gen x silent
__fish_init_cache ic icgen --init
check "silent generator: returns 1" 1 $status
check "silent generator: nothing stored" false (yesno test -e $cache_dir/ic.fish)

make_gen $gen x garbage
__fish_init_cache ic icgen --init
check "unparsable output: returns 1 (caller reports it live)" 1 $status
check "unparsable output: not sourced" "" "$__ic_marker"
check "unparsable output: not stored" false (yesno test -e $cache_dir/ic.fish)
check "unparsable output: no temp file" 0 (count (path filter $cache_dir/*))

__fish_init_cache ic no-such-binary-hopefully --init
check "missing binary: returns 1" 1 $status
check "missing binary: nothing stored" false (yesno test -e $cache_dir/ic.fish)

section "init-cache: opt-out and usage"

reset_state
make_gen $gen v1
for off in 0 off false no n OFF
    set -g __fish_config_init_cache $off
    __fish_init_cache ic icgen --init
    check "__fish_config_init_cache=$off: declined (returns 1)" 1 $status
end
check "opt-out: generator never run by the helper" 0 (runs)
check "opt-out: nothing stored" false (yesno test -e $cache_dir)
for on in 1 on garbage ''
    reset_state
    set -g __fish_config_init_cache $on
    __fish_init_cache ic icgen --init 2>/dev/null
    check "__fish_config_init_cache='$on': cache stays on" 0 $status
end
reset_state
__fish_init_cache
check "no arguments: usage error" 2 $status
__fish_init_cache ic
check "no command: usage error" 2 $status
__fish_init_cache bad/name icgen
check "path in the name: usage error" 2 $status
__fish_init_cache --clear '../x'
check "--clear with a path: usage error" 2 $status
check "usage errors ran nothing" 0 (runs)

section "init-cache: --clear"

__fish_init_cache a icgen --init
__fish_init_cache b icgen --init
check "two entries" 2 (count $cache_dir/*.fish)
__fish_init_cache --clear a
check "--clear <name>: that entry only" b.fish (path basename $cache_dir/*.fish)
__fish_init_cache --clear
check "--clear: all entries" 0 (count (path filter $cache_dir/*.fish))
__fish_init_cache --clear
check "--clear on an empty cache: ok" 0 $status

section "init-cache: unwritable cache location"

reset_state
make_gen $gen v1
# XDG_CACHE_HOME is a regular file, so the dir can never be created.
echo x >$sandbox/notadir
set -l saved $XDG_CACHE_HOME
set -gx XDG_CACHE_HOME $sandbox/notadir
__fish_init_cache ic icgen --init
check "unwritable: still returns 0" 0 $status
check "unwritable: init still sourced" v1 "$__ic_marker"
check "unwritable: nothing created" true (yesno test -f $sandbox/notadir)
set -gx XDG_CACHE_HOME $saved

section "init-cache: XDG_CACHE_HOME unset falls back to \$HOME/.cache"

reset_state
set -e XDG_CACHE_HOME
make_gen $gen v1
__fish_init_cache ic icgen --init
check "stored under HOME/.cache" true (yesno test -f $HOME/.cache/fish-config/init/ic.fish)
set -gx XDG_CACHE_HOME $saved

#   ──────────────────────── config.fish wiring (real blocks) ───────────────────────

# Cut the fzf and direnv blocks out of the real config.fish by their anchors,
# as test-config-env.fish does for the env blocks.
function _cut_block --argument-names start close
    set -l on 0
    while read -l line
        if test $on -eq 0
            string match -rq -- $start $line; and set on 1
        end
        if test $on -eq 1
            printf '%s\n' $line
            test "$line" = "$close"; and break
        end
    end <$repo_root/config.fish
end

set -g work $sandbox/work
command mkdir -p $work/fzf $work/direnv
set -l fzf_src (_cut_block '^    if type -q fzf' '    end')
set -l direnv_src (_cut_block '^    if type -q direnv' '    end')
section "init-cache: config.fish wiring"
check "fzf block found" true (yesno string match -q '*__fish_init_cache fzf fzf --fish*' -- $fzf_src)
check "direnv block found" true (yesno string match -q '*__fish_init_cache direnv direnv hook fish*' -- $direnv_src)
check "fzf block keeps the live fallback" true (yesno string match -q '*fzf --fish | source*' -- $fzf_src)
check "direnv block keeps the live fallback" true (yesno string match -q '*direnv hook fish | source*' -- $direnv_src)
printf '%s\n' $fzf_src >$work/fzf/config.fish
printf '%s\n' $direnv_src >$work/direnv/config.fish

# Stub tools on a private PATH. fzf --version / --fish are steered by the
# FZF_STUB_VERSION environment variable.
set -g toolbin $sandbox/tools
command mkdir -p $toolbin
printf '%s\n' '#!/bin/sh' \
    'echo "fzf $*" >>"$IC_RUNLOG"' \
    'case "$1" in' \
    '  --version) echo "$FZF_STUB_VERSION (stub)" ;;' \
    '  --fish)' \
    '    case "$FZF_STUB_VERSION" in 0.4[0-7]*|0.[0-3]*) echo "unknown option: --fish" >&2; exit 2 ;; esac' \
    '    echo "set -g __fzf_stub_loaded $FZF_STUB_VERSION" ;;' \
    esac >$toolbin/fzf
printf '%s\n' '#!/bin/sh' \
    'echo "direnv $*" >>"$IC_RUNLOG"' \
    'echo "set -g __direnv_stub_loaded yes"' >$toolbin/direnv
command chmod +x $toolbin/fzf $toolbin/direnv
command touch -d '2027-01-01 00:00:00' $toolbin/fzf $toolbin/direnv

# Run a block in a child fish and print what it left behind.
function run_block --argument-names block
    set -l rl $sandbox/blockruns
    set -l opt_out
    set -q __fish_config_init_cache; and set opt_out __fish_config_init_cache=$__fish_config_init_cache
    command env IC_RUNLOG=$rl FZF_STUB_VERSION=$FZF_STUB_VERSION $opt_out \
        XDG_CACHE_HOME=$XDG_CACHE_HOME HOME=$HOME PATH=(string join : $toolbin $__saved_path) \
        fish --no-config -c "set -p fish_function_path $repo_root/functions
source $work/$block/config.fish
echo \"fzf=[\$__fzf_stub_loaded] direnv=[\$__direnv_stub_loaded]\"" 2>&1
end
function block_runs
    test -f $sandbox/blockruns; and count (string match -r . <$sandbox/blockruns); or echo 0
end

reset_state
command rm -f $sandbox/blockruns
set -gx FZF_STUB_VERSION 0.74.0
set -l out (run_block fzf)
check "fzf, cold: init sourced" "fzf=[0.74.0] direnv=[]" "$out"
check "fzf, cold: one --fish run, no --version run" "fzf --fish" (string join , (string split \n -- (string trim (string collect <$sandbox/blockruns))))
check "fzf, cold: stored" true (yesno test -f $cache_dir/fzf.fish)
command rm -f $sandbox/blockruns
set out (run_block fzf)
check "fzf, hot: same init sourced" "fzf=[0.74.0] direnv=[]" "$out"
check "fzf, hot: no fzf process at all" 0 (block_runs)
command rm -f $sandbox/blockruns
set -gx FZF_STUB_VERSION 0.75.0
command touch -d '2027-06-01 00:00:00' $toolbin/fzf
set out (run_block fzf)
check "fzf upgraded: the new init is sourced, not the cached one" "fzf=[0.75.0] direnv=[]" "$out"

reset_state
command rm -f $sandbox/blockruns
set out (run_block direnv)
check "direnv, cold: hook sourced" "fzf=[] direnv=[yes]" "$out"
command rm -f $sandbox/blockruns
set out (run_block direnv)
check "direnv, hot: hook sourced" "fzf=[] direnv=[yes]" "$out"
check "direnv, hot: no direnv process" 0 (block_runs)
command rm -f $sandbox/blockruns
set -g __fish_config_init_cache off
set out (run_block direnv)
check "direnv, opt-out: live hook sourced" "fzf=[] direnv=[yes]" "$out"
check "direnv, opt-out: ran the live way" 1 (block_runs)
set -e __fish_config_init_cache

# An fzf too old for --fish: the helper declines and the original version
# check and hint run, with no cache entry for it.
reset_state
command rm -f $sandbox/blockruns
set -gx FZF_STUB_VERSION 0.40.0
set out (run_block fzf)
check "old fzf: no init sourced" true (yesno string match -q '*fzf=[]*' -- "$out")
check "old fzf: hint printed" true (yesno string match -q '*older than 0.48*' -- "$out")
check "old fzf: nothing cached" false (yesno test -e $cache_dir/fzf.fish)
set -e FZF_STUB_VERSION

set -gx PATH $__saved_path
command rm -rf $sandbox
report
