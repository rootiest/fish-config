#!/usr/bin/env fish
# Copyright (C) 2026 Rootiest
# SPDX-License-Identifier: AGPL-3.0-or-later
#
# MODE: isolated
#
# Small helpers with no suite of their own (#238): the kitty-logging probes
# (__kitty_logging_dir, __kitty_logging_has_watcher, __kitty_logging_version),
# the jobrunner session parser (__jobrunner_sessions) and the .venv
# auto-activation handler (__auto_source_fallback_venv).
#
# Nothing here needs kitty, tmux or screen installed: kitty.conf and watcher
# files are fixtures in a mktemp sandbox, and tmux/screen are stub scripts on
# a PATH that holds nothing else, so the host's real sessions are never
# listed. The venv cases cd between sandbox directories and always return to
# the starting directory.

source (realpath (dirname (status filename)))/lib.fish
set -p fish_function_path $repo_root/functions

set -g work (realpath (mktemp -d))
set -gx HOME $work/home
mkdir -p $HOME
set -g _real_path $PATH
set -g _start_dir $PWD

# =============================================================================
# 1. __kitty_logging_dir
# =============================================================================
section __kitty_logging_dir

set -l saved_xdg $XDG_CONFIG_HOME
set -e KITTY_CONFIG_DIRECTORY

set -gx XDG_CONFIG_HOME $work/xdg
check "XDG_CONFIG_HOME/kitty when no override" $work/xdg/kitty (__kitty_logging_dir)
set -gx KITTY_CONFIG_DIRECTORY $work/kcd
check "KITTY_CONFIG_DIRECTORY wins over XDG" $work/kcd (__kitty_logging_dir)
set -gx KITTY_CONFIG_DIRECTORY ''
check "an empty KITTY_CONFIG_DIRECTORY is ignored" $work/xdg/kitty (__kitty_logging_dir)
set -e KITTY_CONFIG_DIRECTORY
set -gx XDG_CONFIG_HOME ''
check "an empty XDG_CONFIG_HOME falls back to ~/.config/kitty" $HOME/.config/kitty (__kitty_logging_dir)
set -e XDG_CONFIG_HOME
check "no XDG_CONFIG_HOME falls back to ~/.config/kitty" $HOME/.config/kitty (__kitty_logging_dir)
check "always returns 0" 0 (__kitty_logging_dir >/dev/null; echo $status)

# =============================================================================
# 2. __kitty_logging_has_watcher
# =============================================================================
section __kitty_logging_has_watcher

set -gx KITTY_CONFIG_DIRECTORY $work/kitty
set -l conf $work/kitty/kitty.conf

__kitty_logging_has_watcher
check "no config directory returns 1" 1 $status
mkdir -p $work/kitty
__kitty_logging_has_watcher
check "no kitty.conf returns 1" 1 $status

printf 'font_size 12\n' >$conf
__kitty_logging_has_watcher
check "a conf without a watcher returns 1" 1 $status

printf 'font_size 12\n# watcher fish-config-watcher.py\n' >$conf
__kitty_logging_has_watcher
check "a commented-out watcher does not count" 1 $status

printf 'font_size 12\nwatcher_extra foo\n' >$conf
__kitty_logging_has_watcher
check "a longer directive that starts with 'watcher' does not count" 1 $status

printf 'font_size 12\nwatcher fish-config-watcher.py\n' >$conf
__kitty_logging_has_watcher
check "an active watcher returns 0" 0 $status

printf '  \twatcher /path/to/my_own.py\n' >$conf
__kitty_logging_has_watcher
check "an indented user watcher counts too" 0 $status

# Only the top-level kitty.conf is read: a watcher in an included file does
# not count (documented as "the top-level kitty.conf").
printf 'include extra.conf\n' >$conf
printf 'watcher x.py\n' >$work/kitty/extra.conf
__kitty_logging_has_watcher
check "a watcher only in an include is not seen" 1 $status
set -e KITTY_CONFIG_DIRECTORY

# =============================================================================
# 3. __kitty_logging_version
# =============================================================================
section __kitty_logging_version

set -l wf $work/watcher.py
check "a missing file reads 0" 0 (__kitty_logging_version $work/nope.py)
check "no argument reads 0" 0 (__kitty_logging_version)
printf 'import os\n' >$wf
check "a file with no marker reads 0" 0 (__kitty_logging_version $wf)
printf '#!/usr/bin/env python3\n# fish-config-watcher-version: 7\nimport os\n' >$wf
check "the marker's integer is read" 7 (__kitty_logging_version $wf)
printf '# fish-config-watcher-version:12\n' >$wf
check "no space after the colon is fine" 12 (__kitty_logging_version $wf)
printf '# fish-config-watcher-version: abc\n' >$wf
check "a non-numeric marker reads 0" 0 (__kitty_logging_version $wf)
check "output is a single line" 1 (count (__kitty_logging_version $wf))
check "always returns 0" 0 (__kitty_logging_version $work/nope.py >/dev/null; echo $status)
set -gx XDG_CONFIG_HOME $saved_xdg

# =============================================================================
# 4. __jobrunner_sessions
# =============================================================================
section __jobrunner_sessions

set -l jr $work/jr
mkdir -p $jr/none $jr/tmux $jr/screen $jr/both $jr/screen-empty
set -g _jr_log $work/jr.log

# tmux stub: logs its argv, prints two tab-separated sessions.
set -l tmux_stub '#!/bin/sh
printf "%s\n" "$*" >>'$_jr_log'
printf "build\t111\tDetached\tMon Oct 12 09:00:00 2026\n"
printf "web\t222\tAttached\tMon Oct 12 10:00:00 2026\n"
'
# screen stub: the real `screen -ls` layout, including the build that omits
# the date field, and its habit of exiting 1.
set -l screen_stub '#!/bin/sh
printf "There are screens on:\n"
printf "\t12345.long job\t(10/12/2026 09:00:00 AM)\t(Detached)\n"
printf "\t678.web\t(Attached)\n"
printf "2 Sockets in /run/screens/S-user.\n"
exit 1
'
set -l screen_empty_stub '#!/bin/sh
printf "No Sockets found in /run/screens/S-user.\n"
exit 1
'
printf '%s' $tmux_stub >$jr/tmux/tmux
printf '%s' $tmux_stub >$jr/both/tmux
printf '%s' $screen_stub >$jr/screen/screen
printf '%s' $screen_stub >$jr/both/screen
printf '%s' $screen_empty_stub >$jr/screen-empty/screen
chmod +x $jr/*/*

set -gx PATH $jr/none
__jobrunner_sessions >/dev/null
check "neither tmux nor screen returns 1" 1 $status
__jobrunner_sessions tmux >/dev/null
check "explicit tmux when missing returns 1" 1 $status
__jobrunner_sessions screen >/dev/null
check "explicit screen when missing returns 1" 1 $status

set -gx PATH $jr/tmux
set -l rows (__jobrunner_sessions tmux)
check "tmux: exits 0" 0 $status
check "tmux: one row per session" 2 (count $rows)
check "tmux: first row is name/pid/state/started" "build|111|Detached|Mon Oct 12 09:00:00 2026" (string split \t -- $rows[1] | string join '|')
check "tmux: attached state is kept" Attached (string split \t -- $rows[2])[3]
check "tmux: asks for the tab-separated format" true (string match -q 'list-sessions -F #{session_name}*#{pid}*' -- (string collect <$_jr_log); and echo true; or echo false)
__jobrunner_sessions nano >/dev/null
check "an unknown tool returns 1" 1 $status

set -gx PATH $jr/both
check "auto-detect prefers tmux" build (__jobrunner_sessions | string split -f1 \t)[1]

set -gx PATH $jr/screen
set rows (__jobrunner_sessions)
check "screen: auto-detected, exits 0 despite screen -ls exiting 1" 0 $status
check "screen: one row per session, headers skipped" 2 (count $rows)
check "screen: name with a space, pid, state, date" "long job|12345|Detached|10/12/2026 09:00:00 AM" (string split \t -- $rows[1] | string join '|')
check "screen: a dateless row has an empty start time" "web|678|Attached|" (string split \t -- $rows[2] | string join '|')

set -gx PATH $jr/screen-empty
set rows (__jobrunner_sessions screen)
check "screen: no sessions exits 0" 0 $status
check "screen: no sessions prints nothing" 0 (count $rows)
set -gx PATH $_real_path

# =============================================================================
# 5. __auto_source_fallback_venv
# =============================================================================
section __auto_source_fallback_venv

# A fake project whose .venv activate script records activation the way the
# real one does: it sets VIRTUAL_ENV and defines deactivate.
set -l proj $work/proj
mkdir -p $proj/.venv/bin $proj/sub {$proj}2 $work/elsewhere $work/direnv-proj/.venv/bin
set -l activate 'set -gx VIRTUAL_ENV (builtin realpath .venv)
set -g _venv_activations (math $_venv_activations + 1)
function deactivate
    set -e VIRTUAL_ENV
    set -g _venv_deactivations (math $_venv_deactivations + 1)
    functions -e deactivate
end
'
printf '%s' $activate >$proj/.venv/bin/activate.fish
printf '%s' $activate >$work/direnv-proj/.venv/bin/activate.fish
touch $work/direnv-proj/.envrc
set -g _venv_activations 0
set -g _venv_deactivations 0
set -e VIRTUAL_ENV DIRENV_DIR

# Loading the function registers its --on-variable PWD handler; from here on
# every builtin cd fires it, exactly as in an interactive shell.
check "the handler autoloads" true (functions -q __auto_source_fallback_venv; and echo true; or echo false)

builtin cd $proj
check "entering a project activates its .venv" (builtin realpath $proj/.venv) "$VIRTUAL_ENV"
check "activation happened once" 1 $_venv_activations
builtin cd $proj/sub
check "a subdirectory keeps the venv" (builtin realpath $proj/.venv) "$VIRTUAL_ENV"
check "a subdirectory does not re-activate" 1 $_venv_activations
builtin cd $work/elsewhere
check "leaving the project deactivates" "" "$VIRTUAL_ENV"
check "deactivate ran once" 1 $_venv_deactivations

# A sibling sharing the project's name as a prefix is outside it (#313).
builtin cd $proj
builtin cd {$proj}2
check "a prefix-sharing sibling deactivates" "" "$VIRTUAL_ENV"
check "deactivate ran again" 2 $_venv_deactivations
builtin cd $work/elsewhere

builtin cd $work/direnv-proj
check "a directory with .envrc is left to direnv" "" "$VIRTUAL_ENV"
builtin cd $work/elsewhere
set -gx DIRENV_DIR -$proj
builtin cd $proj
check "DIRENV_DIR set means hands off" "" "$VIRTUAL_ENV"
set -e DIRENV_DIR
builtin cd $work/elsewhere

# Calling it inside a command substitution is a no-op (no activation leaks
# out of a subshell-like context).
builtin cd $proj
set -e VIRTUAL_ENV
functions -e deactivate
set -l discard (__auto_source_fallback_venv)
check "inside a command substitution it does nothing" "" "$VIRTUAL_ENV"
builtin cd $work/elsewhere

# C2 guard: with the autoexec category off, no automatic activation.
source $repo_root/conf.d/__fish_config_op_registry.fish
set -g __fish_config_op_autoexec 0
builtin cd $proj
check "autoexec disabled: no activation" "" "$VIRTUAL_ENV"
builtin cd $work/elsewhere
set -g __fish_config_op_autoexec 1
builtin cd $proj
check "autoexec re-enabled: activates again" (builtin realpath $proj/.venv) "$VIRTUAL_ENV"
builtin cd $work/elsewhere
set -e __fish_config_op_autoexec

builtin cd $_start_dir
functions -e __auto_source_fallback_venv
command rm -rf $work
report
