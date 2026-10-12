#!/usr/bin/env fish
# Copyright (C) 2026 Rootiest
# SPDX-License-Identifier: AGPL-3.0-or-later
#
# MODE: isolated
#
# Coverage for the vendored sponge plugin's runtime (issue #238): the two
# filters (sponge_filter_failed, sponge_filter_matched), the event hooks
# (_sponge_on_preexec, _sponge_on_postexec, _sponge_on_prompt,
# _sponge_on_exit) and the purge helpers (_sponge_remove_from_history,
# _sponge_clear_state). test-sponge-privacy.fish covers the pattern
# migrations in conf.d/sponge_privacy.fish; this suite covers what sponge
# then does with those patterns: which commands it queues and which history
# entries it actually deletes.
#
# Runs isolated. The hooks call `builtin history`, which a test-local
# function cannot shadow, so the suite works on a real but throwaway history:
# it re-executes itself in a child fish whose XDG_DATA_HOME, XDG_CONFIG_HOME
# and HOME all point into a temp dir, with its own fish_history session name.
# XDG_DATA_HOME is only read at startup (setting it mid-process does not move
# the history file), hence the re-exec rather than a `set -gx`. The sponge
# settings are set as globals here, never universals, and conf.d/sponge.fish
# (which writes universals) is not sourced.

if not set -q __FISH_CONFIG_SPONGE_SANDBOX
    set -l sb (mktemp -d)
    mkdir -p $sb/data $sb/cfg $sb/home
    env __FISH_CONFIG_SPONGE_SANDBOX=$sb XDG_DATA_HOME=$sb/data \
        XDG_CONFIG_HOME=$sb/cfg HOME=$sb/home \
        fish --no-config (status filename)
    set -l rc $status
    command rm -rf $sb
    exit $rc
end

source (realpath (dirname (status filename)))/lib.fish
set -p fish_function_path $repo_root/functions

set -g fish_history sponge_hooks_test

# The defaults conf.d/sponge.fish would install, as globals.
set -g sponge_delay 2
set -g sponge_purge_only_on_exit false
set -g sponge_filters sponge_filter_failed sponge_filter_matched
set -g sponge_allow_previously_successful true
set -g sponge_successful_exit_codes 0
set -g sponge_regex_patterns hunter2 '(?i)authorization:'
set -g _sponge_queue

function in_history --argument-names cmd
    contains -- $cmd $history; and echo true; or echo false
end

# run_cmd CMD STATUS : drive one command through the preexec/postexec pair
# the way fish does, with $status set to STATUS when postexec starts.
function run_cmd --argument-names cmd code
    _sponge_on_preexec $cmd
    builtin history append -- $cmd
    if test $code -eq 0
        true
    else
        false
    end
    _sponge_on_postexec
end

#   ──────── sponge_filter_failed ────────

section sponge_filter_failed

sponge_filter_failed cmd 1 false
check "failed, new command -> filtered (0)" 0 $status
sponge_filter_failed cmd 0 false
check "successful command -> kept (1)" 1 $status
sponge_filter_failed cmd 1 true
check "failed but previously in history -> kept (1)" 1 $status

set -g sponge_allow_previously_successful false
sponge_filter_failed cmd 1 true
check "allow_previously_successful=false -> filtered even if in history" 0 $status
set -g sponge_allow_previously_successful true

set -g sponge_successful_exit_codes 0 130
sponge_filter_failed cmd 130 false
check "custom successful code 130 -> kept (1)" 1 $status
sponge_filter_failed cmd 2 false
check "code outside the custom list -> filtered (0)" 0 $status
set -g sponge_successful_exit_codes 0

#   ──────── sponge_filter_matched ────────

section sponge_filter_matched

sponge_filter_matched 'mysql --password hunter2'
check "secret pattern matches -> filtered (0)" 0 $status
sponge_filter_matched 'curl -H "Authorization: Bearer x" host'
check "case-insensitive pattern matches -> filtered (0)" 0 $status
sponge_filter_matched 'ls -la'
check "no pattern matches -> kept (1)" 1 $status
sponge_filter_matched --hunter2
check "command starting with -- is matched, not parsed as an option" 0 $status

set -l saved_patterns $sponge_regex_patterns
set -g sponge_regex_patterns
sponge_filter_matched 'echo hunter2'
check "empty pattern list -> kept (1)" 1 $status
set -g sponge_regex_patterns $saved_patterns

#   ──────── _sponge_clear_state ────────

section _sponge_clear_state

set -g _sponge_current_command x
set -g _sponge_current_command_exit_code 3
set -g _sponge_current_command_previously_in_history true
_sponge_clear_state
check "current command erased" false (set -q _sponge_current_command; and echo true; or echo false)
check "exit code erased" false (set -q _sponge_current_command_exit_code; and echo true; or echo false)
check "previously_in_history erased" false (set -q _sponge_current_command_previously_in_history; and echo true; or echo false)

#   ──────── _sponge_on_preexec ────────

section _sponge_on_preexec

builtin history append 'echo already-here'
_sponge_on_preexec 'echo already-here'
check "records the current command" 'echo already-here' "$_sponge_current_command"
check "command in history -> previously_in_history=true" true $_sponge_current_command_previously_in_history

_sponge_on_preexec 'echo brand-new'
check "command not in history -> previously_in_history=false" false $_sponge_current_command_previously_in_history

set -g _sponge_queue 'echo already-here'
_sponge_on_preexec 'echo already-here'
check "in history but queued for deletion -> treated as new" false $_sponge_current_command_previously_in_history
set -g _sponge_queue

_sponge_on_preexec 'echo already'
check "exact match only: a prefix is not 'in history'" false $_sponge_current_command_previously_in_history

#   ──────── _sponge_on_postexec ────────

section _sponge_on_postexec

set -g _sponge_queue
_sponge_on_preexec 'echo brand-new'
false
_sponge_on_postexec
check "captures the command's exit status" 1 $_sponge_current_command_exit_code
check "failed new command is queued" 'echo brand-new' "$_sponge_queue[1]"

_sponge_on_preexec 'echo fine'
true
_sponge_on_postexec
check "successful harmless command queues a blank placeholder" 2 (count $_sponge_queue)
check "placeholder is the empty string" '' "$_sponge_queue[1]"

_sponge_on_preexec 'echo hunter2'
true
_sponge_on_postexec
check "successful command matching a secret pattern is queued" 'echo hunter2' "$_sponge_queue[1]"

_sponge_on_preexec 'echo brand-new'
false
_sponge_on_postexec
check "re-run command is not queued twice" 1 (count (string match -- 'echo brand-new' $_sponge_queue))
check "re-run command moves to the front" 'echo brand-new' "$_sponge_queue[1]"

#   ──────── _sponge_remove_from_history ────────

section _sponge_remove_from_history

builtin history append 'echo oldest-secret'
builtin history append 'echo mid-secret'
builtin history append 'echo newest-secret'
set -g _sponge_queue 'echo newest-secret' 'echo mid-secret' 'echo oldest-secret'
set -g sponge_delay 2
_sponge_remove_from_history
check "queue trimmed down to sponge_delay" 2 (count $_sponge_queue)
check "oldest queued entry deleted from history" false (in_history 'echo oldest-secret')
check "entries within the delay window survive" true (in_history 'echo mid-secret')
check "newest entry survives" true (in_history 'echo newest-secret')

set -g sponge_delay 0
_sponge_remove_from_history
check "delay 0 empties the queue" 0 (count $_sponge_queue)
check "delay 0 deletes every queued entry" false (in_history 'echo mid-secret')
check "...including the newest" false (in_history 'echo newest-secret')

builtin history append 'echo keep-me'
set -g _sponge_queue ''
_sponge_remove_from_history
check "blank placeholder deletes nothing" true (in_history 'echo keep-me')

builtin history append 'echo exact'
builtin history append 'echo exact-plus'
set -g _sponge_queue 'echo exact'
_sponge_remove_from_history
check "deletion is exact: target removed" false (in_history 'echo exact')
check "deletion is exact: longer entry untouched" true (in_history 'echo exact-plus')

#   ──────── _sponge_on_prompt ────────

section _sponge_on_prompt

set -g sponge_delay 0
builtin history append 'echo prompt-secret'
set -g sponge_purge_only_on_exit true
set -g _sponge_queue 'echo prompt-secret'
_sponge_on_prompt
check "purge_only_on_exit=true: prompt leaves the queue alone" 1 (count $_sponge_queue)
check "purge_only_on_exit=true: entry still in history" true (in_history 'echo prompt-secret')

set -g sponge_purge_only_on_exit false
_sponge_on_prompt
check "purge_only_on_exit=false: prompt purges" false (in_history 'echo prompt-secret')
check "purge_only_on_exit=false: queue drained" 0 (count $_sponge_queue)

#   ──────── _sponge_on_exit ────────

section _sponge_on_exit

set -g sponge_delay 5
builtin history append 'echo exit-a'
builtin history append 'echo exit-b'
set -g _sponge_queue 'echo exit-b' 'echo exit-a'
_sponge_on_exit
check "exit purges regardless of sponge_delay" false (in_history 'echo exit-a')
check "exit purges the newest entry too" false (in_history 'echo exit-b')
check "exit drains the queue" 0 (count $_sponge_queue)
check "exit does not change the global sponge_delay" 5 $sponge_delay

#   ──────── End to end ────────

section "sponge: end to end"

set -g sponge_delay 0
set -g sponge_purge_only_on_exit false
set -g _sponge_queue
run_cmd 'export TOKEN=hunter2' 0
run_cmd 'ls /nonexistent-e2e' 2
run_cmd 'echo harmless-e2e' 0
_sponge_on_prompt
check "secret command scrubbed from history" false (in_history 'export TOKEN=hunter2')
check "failed command scrubbed from history" false (in_history 'ls /nonexistent-e2e')
check "harmless successful command kept" true (in_history 'echo harmless-e2e')

builtin history append 'git push'
run_cmd 'git push' 1
_sponge_on_prompt
check "previously-successful command that now fails is kept" true (in_history 'git push')

report
