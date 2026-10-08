#!/usr/bin/env fish
# Copyright (C) 2026 Rootiest
# SPDX-License-Identifier: AGPL-3.0-or-later
#
# Coverage for conf.d/wakatime.fish: the postexec handler is registered only
# when a wakatime CLI exists (resolved once, with a late retry for a $PATH that
# config.fish extends after conf.d), and the handler honours
# FISH_WAKATIME_DISABLED, DO_NOT_TRACK, DISABLE_TELEMETRY and
# FISH_WAKATIME_PROJECT.
#
# Runs isolated (no `# MODE:` marker). Every case drives a throwaway
# `fish --no-config -i` child with a fake $HOME and a $PATH holding only git
# and a stub `wakatime` that appends its arguments to a log. The real
# wakatime CLI is never reachable, so no activity is ever sent.

source (realpath (dirname (status filename)))/lib.fish

set -l sandbox (mktemp -d)
set -l base_bin $sandbox/base-bin # git only: "no wakatime installed"
set -l stub_bin $sandbox/stub-bin # a stub wakatime
set -l late_bin $sandbox/late-bin # a stub wakatime that joins $PATH after load
set -l fake_home $sandbox/home
set -l log $sandbox/wakatime.log
set -l child $sandbox/child.fish
set -l fish_bin (command -s fish)
mkdir -p $base_bin $stub_bin $late_bin $fake_home/.wakatime
ln -s (command -s git) $base_bin/git

for d in $stub_bin $late_bin
    printf '%s\n' '#!/bin/sh' 'echo "$@" >>"$WK_LOG"' >$d/wakatime
    chmod +x $d/wakatime
end
printf '%s\n' '#!/bin/sh' 'echo "$@" >>"$WK_LOG"' >$fake_home/.wakatime/wakatime-cli.stub

# A git work tree whose directory name stands in for a private repo name.
set -l repo $sandbox/secret-client-repo
mkdir -p $repo
git -C $repo init -q

# The child script. Environment inputs: WK_REPO, WK_LATE_PATH (prepended to
# $PATH after load), WK_CWD, WK_CMD (fired through fish_postexec).
printf '%s\n' \
    'set -p fish_function_path $WK_REPO/functions' \
    'source $WK_REPO/conf.d/__fish_config_op_registry.fish' \
    'source $WK_REPO/conf.d/wakatime.fish' \
    'echo "load="(functions -q __register_wakatime_fish_before_exec; and echo yes; or echo no)' \
    'if set -q WK_LATE_PATH' \
    '    set -gx PATH $WK_LATE_PATH $PATH' \
    end \
    'emit fish_prompt' \
    'echo "prompt="(functions -q __register_wakatime_fish_before_exec; and echo yes; or echo no)' \
    'echo "retry="(functions -q __wakatime_fish_late_resolve; and echo yes; or echo no)' \
    'if set -q WK_CWD' \
    '    cd $WK_CWD' \
    end \
    'if set -q WK_CMD' \
    '    emit fish_postexec "$WK_CMD"' \
    end >$child

# run_wk [VAR=val ...]: runs the child with a scrubbed environment. Sets
# wk_out (child stdout lines). $PATH is $base_bin plus whatever PATH=... asks.
function run_wk --inherit-variable sandbox --inherit-variable base_bin --inherit-variable fake_home --inherit-variable log --inherit-variable child --inherit-variable fish_bin --inherit-variable repo_root
    command rm -f $log
    set -g wk_out (env -u DO_NOT_TRACK -u DISABLE_TELEMETRY -u FISH_WAKATIME_DISABLED -u FISH_WAKATIME_PROJECT \
        HOME=$fake_home XDG_CONFIG_HOME=$sandbox/cfg XDG_DATA_HOME=$sandbox/data \
        PATH=$base_bin TERM=xterm WK_REPO=$repo_root WK_LOG=$log $argv \
        $fish_bin --no-config -i $child 2>/dev/null)
end

# wk_field NAME: value of a "NAME=value" line from the last run_wk.
function wk_field
    string replace -r -- "^$argv[1]=" '' (string match -- "$argv[1]=*" $wk_out)
end

# wk_wait: the stub runs in a disowned background job; give it a moment.
function wk_wait --inherit-variable log
    for i in (seq 30)
        test -s $log; and return 0
        sleep 0.1
    end
    return 1
end

section "wakatime: handler registration"

run_wk
check "no CLI: not registered at load" no (wk_field load)
check "no CLI: still not registered after the first prompt" no (wk_field prompt)
check "no CLI: the retry handler removes itself" no (wk_field retry)

run_wk PATH=$base_bin:$stub_bin
check "CLI on PATH: registered at load" yes (wk_field load)
check "CLI on PATH: no retry handler left" no (wk_field retry)

run_wk WK_LATE_PATH=$late_bin
check "CLI on PATH only after load: not registered at load" no (wk_field load)
check "CLI on PATH only after load: registered on the first prompt" yes (wk_field prompt)
check "CLI on PATH only after load: the retry handler removes itself" no (wk_field retry)

mv $fake_home/.wakatime/wakatime-cli.stub $fake_home/.wakatime/wakatime-cli
chmod +x $fake_home/.wakatime/wakatime-cli
run_wk
check "~/.wakatime/wakatime-cli fallback: registered at load" yes (wk_field load)
command rm $fake_home/.wakatime/wakatime-cli

section "wakatime: handler behaviour"

set -l ok PATH=$base_bin:$stub_bin WK_CWD=$repo/.. WK_CMD="ls -la" WK_LOG=$log

run_wk $ok
wk_wait
check "control: the stub is invoked" true (test -s $log; and echo true; or echo false)
check "control: outside a repo the project is Terminal" true (string match -q -- '*--project Terminal*' (cat $log); and echo true; or echo false)
check "control: the first word is the entity" true (string match -q -- '*--entity ls*' (cat $log); and echo true; or echo false)

run_wk $ok WK_CWD=$repo
wk_wait
check "in a repo: the repository directory name is the project" true (string match -q -- '*--project secret-client-repo*' (cat $log); and echo true; or echo false)

run_wk $ok WK_CWD=$repo FISH_WAKATIME_PROJECT=work
wk_wait
check "FISH_WAKATIME_PROJECT: constant project is sent" true (string match -q -- '*--project work*' (cat $log); and echo true; or echo false)
check "FISH_WAKATIME_PROJECT: repository name is not sent" false (string match -q -- '*secret-client-repo*' (cat $log); and echo true; or echo false)

# Suppressed runs: nothing may reach the stub. The sleep gives a wrongly
# started background job time to write before we look.
for opt_out in FISH_WAKATIME_DISABLED=1 DO_NOT_TRACK=1 DISABLE_TELEMETRY=1 DO_NOT_TRACK=true
    run_wk $ok $opt_out
    sleep 0.5
    check "$opt_out: nothing is sent" false (test -s $log; and echo true; or echo false)
end

# A falsy value is not an opt-out.
run_wk $ok DO_NOT_TRACK=0
wk_wait
check "DO_NOT_TRACK=0: still sent" true (test -s $log; and echo true; or echo false)

command rm -rf $sandbox
report
