#!/usr/bin/env fish
# Copyright (C) 2026 Rootiest
# SPDX-License-Identifier: AGPL-3.0-or-later
#
# MODE: isolated
#
# Issue #237: per-shell startup work that did not need to happen.
#
#   * __fish_config_sync_logging touches the C5 sentinel only when its state
#     has to change, so the common already-in-sync start forks no mkdir,
#     touch or rm.
#   * __fish_config_sync_logging --startup skips the paru/yay wrapper
#     delegation: fish sources conf.d/pkg-wrappers.fish itself right after
#     conf.d/logging-events.fish, so delegating there ran it twice per start.
#
# mkdir/touch/rm/_fish_source_scoped/_tmux_pipe_log are recording stubs that
# still perform the real action (through `command`), so the assertions can
# say both "was not called" and "the end state is right". Everything runs
# under a throwaway XDG_CONFIG_HOME.

source (realpath (dirname (status filename)))/lib.fish
set -p fish_function_path $repo_root/functions
source $repo_root/conf.d/__fish_config_op_registry.fish

set -g sandbox (mktemp -d)
set -gx HOME $sandbox/home
set -gx XDG_CONFIG_HOME $sandbox/xdgcfg
command mkdir -p $HOME
set -g sentinel $XDG_CONFIG_HOME/fish/.logging_disabled

set -g calls
function mkdir
    set -ga calls "mkdir $argv"
    command mkdir $argv
end
function touch
    set -ga calls "touch $argv"
    command touch $argv
end
function rm
    set -ga calls "rm $argv"
    command rm $argv
end
function _fish_source_scoped
    set -ga calls "source $argv"
end
function _tmux_pipe_log
    set -ga calls tmux_pipe_log
end

function yesno
    if $argv
        echo true
    else
        echo false
    end
end

function reset_c5
    set -e __fish_config_opinionated
    set -e __fish_config_op_logging
    set -g calls
end

section "startup-work: sentinel absent, logging off (the first start)"

reset_c5
__fish_config_sync_logging --startup
check "exits 0" 0 $status
check "sentinel created" true (yesno test -f $sentinel)
check "config dir created when missing" true (yesno test -d $XDG_CONFIG_HOME/fish)
check "one mkdir and one touch" "mkdir -p $XDG_CONFIG_HOME/fish,touch $sentinel" (string join , $calls)

section "startup-work: sentinel present, logging off (every later start)"

reset_c5
__fish_config_sync_logging --startup
check "exits 0" 0 $status
check "sentinel still present" true (yesno test -f $sentinel)
check "no mkdir, no touch, no rm" "" (string join , $calls)

section "startup-work: sentinel present, logging on"

reset_c5
set -g __fish_config_op_logging 1
__fish_config_sync_logging --startup
check "exits 0" 0 $status
check "sentinel removed" false (yesno test -e $sentinel)
check "rm called once for it" "rm -f $sentinel,tmux_pipe_log" (string join , $calls)

section "startup-work: sentinel absent, logging on"

reset_c5
set -g __fish_config_op_logging 1
__fish_config_sync_logging --startup
check "exits 0" 0 $status
check "still no sentinel" false (yesno test -e $sentinel)
check "no rm for a missing sentinel" tmux_pipe_log (string join , $calls)

section "startup-work: dangling-symlink sentinel is still cleaned up"

reset_c5
ln -s $sandbox/nowhere $sentinel
set -g __fish_config_op_logging 1
__fish_config_sync_logging --startup
check "dangling symlink removed" false (yesno test -L $sentinel)

section "startup-work: --startup skips the wrapper delegation"

reset_c5
__fish_config_sync_logging --startup
check "--startup, logging off: pkg-wrappers not sourced" 0 (count (string match -- 'source *' $calls))
reset_c5
set -g __fish_config_op_logging 1
__fish_config_sync_logging --startup
check "--startup, logging on: pkg-wrappers not sourced" 0 (count (string match -- 'source *' $calls))

section "startup-work: without --startup the delegation still runs"

reset_c5
__fish_config_sync_logging
check "logging off: exits 0" 0 $status
check "logging off: pkg-wrappers sourced once" 1 (count (string match -- 'source *' $calls))
check "logging off: the right file" true (yesno string match -q -- "source $__fish_config_dir/conf.d/pkg-wrappers.fish" $calls)
reset_c5
set -g __fish_config_op_logging 1
__fish_config_sync_logging
check "logging on: pkg-wrappers sourced once" 1 (count (string match -- 'source *' $calls))

section "startup-work: wiring"

set -l events (string split \n -- (string collect <$repo_root/conf.d/logging-events.fish))
check "logging-events.fish passes --startup on its start-up call" 1 \
    (count (string match -- '__fish_config_sync_logging --startup' $events))
check "variable-change handlers keep the full sync" 2 \
    (count (string match -- '    __fish_config_sync_logging' $events))
# The skip is only sound while fish sources pkg-wrappers.fish after
# logging-events.fish: conf.d runs alphabetically.
check "pkg-wrappers.fish sorts after logging-events.fish" logging-events.fish,pkg-wrappers.fish \
    (string join , (path sort pkg-wrappers.fish logging-events.fish))

command rm -rf $sandbox
report
