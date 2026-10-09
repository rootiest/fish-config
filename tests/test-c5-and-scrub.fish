#!/usr/bin/env fish
# Copyright (C) 2026 Rootiest
# SPDX-License-Identifier: AGPL-3.0-or-later
#
# Regression coverage for issue #238 (functions with no or weak test cover):
#
#   * gitignore-scrub: untracks files .gitignore now ignores. It rewrites the
#     git index, so every call here runs inside a throwaway repo and the
#     assertions pin what it untracks, that working-tree files survive, and
#     that nothing outside that repo is touched.
#   * The C5 (terminal logging) opt-in invariant: logging is OFF unless
#     __fish_config_op_logging is explicitly truthy. The cascade itself is
#     covered by test-guards.fish; this suite checks the real consumers
#     (__fish_config_op_enabled for the registered C5 identities,
#     __fish_config_sync_logging, _zellij_dump_log).
#   * _prune_terminal_logs: the safety properties not covered by
#     test-log-writers.fish (scope of deletion, boundary counts).
#
# Runs isolated (no `# MODE:` marker). HOME is deliberately re-pointed at a
# throwaway directory: the driver leaves the real HOME in place, and several
# of these functions default to paths under it. tmux and zellij are fakes.

source (realpath (dirname (status filename)))/lib.fish
set -p fish_function_path $repo_root/functions
source $repo_root/conf.d/__fish_config_op_registry.fish

set -g TMPDIRS
set -g sandbox (mktemp -d)
set -ga TMPDIRS $sandbox
set -gx HOME $sandbox/home
set -gx XDG_CONFIG_HOME $sandbox/xdgcfg
set -gx XDG_DATA_HOME $sandbox/xdgdata
command mkdir -p $HOME $XDG_CONFIG_HOME $XDG_DATA_HOME
set -g real_cwd $PWD

# Never sign, never read the real gitconfig, never run hooks.
set -gx GIT_CONFIG_GLOBAL /dev/null
set -gx GIT_CONFIG_SYSTEM /dev/null
set -gx GIT_CONFIG_NOSYSTEM 1
set -gx GIT_AUTHOR_NAME t
set -gx GIT_AUTHOR_EMAIL t@t
set -gx GIT_COMMITTER_NAME t
set -gx GIT_COMMITTER_EMAIL t@t
set -gx GIT_CONFIG_COUNT 2
set -gx GIT_CONFIG_KEY_0 commit.gpgsign
set -gx GIT_CONFIG_VALUE_0 false
set -gx GIT_CONFIG_KEY_1 init.defaultBranch
set -gx GIT_CONFIG_VALUE_1 main

function yesno
    if $argv
        echo true
    else
        echo false
    end
end

section "c5-and-scrub: preconditions"

# Without the registry __fish_config_op_enabled fail-opens, so every C5 check
# below would pass or fail for the wrong reason.
check "registry is loaded" 66 (count $__fish_config_op_registry_keys)
check "HOME is the sandbox" $sandbox/home "$HOME"

#   ───────────────────────────── gitignore-scrub ─────────────────────────────

# Make a repo with tracked files a.log b.log keep.txt, then ignore *.log.
function new_scrub_repo
    set -l d (mktemp -d)
    set -ga TMPDIRS $d
    command git -C $d init -q
    command git -C $d config user.email t@t
    command git -C $d config user.name t
    command git -C $d config commit.gpgsign false
    command git -C $d config core.hooksPath /dev/null
    echo a >$d/a.log
    echo b >$d/b.log
    echo keep >$d/keep.txt
    command git -C $d add -A
    command git -C $d commit -q -m init
    echo '*.log' >$d/.gitignore
    printf '%s\n' $d
end

# Run gitignore-scrub from inside $repo, restoring the cwd afterwards. Refuses
# to run outside the sandbox, so a bug in a test can never point the index
# rewrite at a real checkout.
function scrub_in --argument-names repo
    # TMPDIRS entries come from mktemp, so they live next to $sandbox rather
    # than under it; allow exactly those.
    contains -- $repo $TMPDIRS; or begin
        echo "refusing: $repo is not a registered throwaway dir" >&2
        return 99
    end
    cd $repo
    gitignore-scrub $argv[2..-1]
    set -l rc $status
    cd $real_cwd
    return $rc
end

function tracked --argument-names repo
    command git -C $repo ls-files | string join ,
end

section "gitignore-scrub: usage"

set -l out (gitignore-scrub --help | string collect)
check "--help exits 0" 0 $status
check "--help shows usage" true (yesno string match -q '*Usage:*' -- $out)

set -l r (new_scrub_repo)
scrub_in $r -w -f 2>/dev/null
check "-w with -f is rejected (exit 2)" 2 $status
scrub_in $r -f -i 2>/dev/null
check "-f with -i is rejected (exit 2)" 2 $status
scrub_in $r --bogus 2>/dev/null
check "unknown option is rejected (exit 2)" 2 $status
check "rejected calls changed nothing" a.log,b.log,keep.txt (tracked $r)

section "gitignore-scrub: not a git repository"

set -l plain (mktemp -d)
set -ga TMPDIRS $plain
set -l err (scrub_in $plain -f 2>&1 >/dev/null | string collect)
scrub_in $plain -f >/dev/null 2>&1
check "outside a repo exits 1" 1 $status
check "outside a repo reports an error" true (yesno string match -q '*Not a git repository*' -- $err)

section "gitignore-scrub: --warn is read-only"

set -l r (new_scrub_repo)
set -l out (scrub_in $r --warn | string collect)
scrub_in $r --warn >/dev/null
check "--warn with matches exits 1" 1 $status
check "--warn names a.log" true (yesno string match -q '*a.log is tracked but ignored*' -- $out)
check "--warn names b.log" true (yesno string match -q '*b.log is tracked but ignored*' -- $out)
check "--warn does not name unignored keep.txt" false (yesno string match -q '*keep.txt*' -- $out)
check "--warn leaves the index alone" a.log,b.log,keep.txt (tracked $r)
check "--warn leaves the working tree alone" a (cat $r/a.log)

section "gitignore-scrub: clean repo"

set -l r (new_scrub_repo)
echo '*.nomatch' >$r/.gitignore
scrub_in $r --warn >/dev/null
check "--warn with no matches exits 0" 0 $status
scrub_in $r --force >/dev/null
check "--force with no matches exits 0" 0 $status
check "no matches: index unchanged" a.log,b.log,keep.txt (tracked $r)

section "gitignore-scrub: --force"

set -l r (new_scrub_repo)
# A second, unrelated repo and a file outside any repo must be untouched.
set -l other (new_scrub_repo)
echo outside >$sandbox/outside.log
set -l other_before (tracked $other)
set -l out (scrub_in $r --force | string collect)
check "--force exits 0" 0 $status
check "--force reports the count" true (yesno string match -q '*Untracked 2 file(s)*' -- $out)
check "--force untracked only the ignored files" keep.txt (tracked $r)
check "--force keeps a.log in the working tree" a (cat $r/a.log)
check "--force keeps b.log in the working tree" b (cat $r/b.log)
check "--force keeps keep.txt in the working tree" keep (cat $r/keep.txt)
check "--force did not touch another repo's index" $other_before (tracked $other)
check "--force did not touch a file outside the repo" outside (cat $sandbox/outside.log)
scrub_in $r --force >/dev/null
check "--force is idempotent (second run, nothing left)" 0 $status

section "gitignore-scrub: --force handles awkward file names"

set -l r (new_scrub_repo)
echo x >"$r/we ird.log"
command git -C $r add -f -- "we ird.log"
scrub_in $r --force >/dev/null
check "name with a space is untracked" keep.txt (tracked $r)
check "name with a space survives on disk" true (yesno test -f "$r/we ird.log")

section "gitignore-scrub: skip list and --reset"

set -l r (new_scrub_repo)
command git -C $r config --local --add gitignore-scrub.skip a.log
set -l out (scrub_in $r --warn | string collect)
check "--warn skips a remembered file" false (yesno string match -q '*a.log*' -- $out)
check "--warn still reports the other match" true (yesno string match -q '*b.log*' -- $out)
scrub_in $r --force >/dev/null
check "--force honours the skip list" a.log,keep.txt (tracked $r)

set -l r (new_scrub_repo)
command git -C $r config --local --add gitignore-scrub.skip a.log
scrub_in $r --reset --force >/dev/null
check "--reset reconsiders skipped files" keep.txt (tracked $r)
check "--reset clears the skip list" "" (command git -C $r config --local --get-all gitignore-scrub.skip | string collect)

section "gitignore-scrub: interactive prompts"

set -l r (new_scrub_repo)
echo n | scrub_in $r >/dev/null
check "declining leaves the index alone" a.log,b.log,keep.txt (tracked $r)
check "declining remembers both files" a.log,b.log (command git -C $r config --local --get-all gitignore-scrub.skip | string join ,)
scrub_in $r --warn >/dev/null
check "a declined file is not offered again" 0 $status

set -l r (new_scrub_repo)
echo y | scrub_in $r >/dev/null
check "confirming untracks every match" keep.txt (tracked $r)
check "confirming keeps files on disk" a,b (cat $r/a.log $r/b.log | string join ,)

set -l r (new_scrub_repo)
printf 'y\nn\n' | scrub_in $r --individual >/dev/null
check "--individual: yes untracks the first, no keeps the second" b.log,keep.txt (tracked $r)
check "--individual: the declined file is remembered" b.log (command git -C $r config --local --get-all gitignore-scrub.skip | string join ,)
check "--individual: both files survive on disk" a,b (cat $r/a.log $r/b.log | string join ,)

section "gitignore-scrub: GITIGNORE_SCRUB_LIMIT"

set -l r (new_scrub_repo)
set -lx GITIGNORE_SCRUB_LIMIT 2
scrub_in $r --force >/dev/null
check "repo above the limit: exits 0" 0 $status
check "repo above the limit: index untouched" a.log,b.log,keep.txt (tracked $r)
set -lx GITIGNORE_SCRUB_LIMIT 4
scrub_in $r --force >/dev/null
check "repo within the limit: scrubbed" keep.txt (tracked $r)
set -e GITIGNORE_SCRUB_LIMIT

#   ─────────────────────── C5 logging is opt-in (consumers) ───────────────────────

function reset_c5
    set -e __fish_config_op_logging __fish_config_opinionated __fish_config_op_logging_terminal_capture __fish_config_op_logging_multiplexer_capture __fish_op_warned_values
end

# Both the 'enabled' and the 'disabled' answer for the identities that carry
# the C5 tags. These go through the registry, unlike the cascade tests.
section "C5: __fish_config_op_enabled for registered logging identities"

for key in "__fish_config_sync_logging:" "_zellij_dump_log:" tmux-logging: kitty-logging:
    set -l parts (string split -m 1 : -- $key)
    __fish_config_op_registry_lookup $parts[1] $parts[2] >/dev/null
    check "$parts[1]: has a registry entry" 0 $status

    reset_c5
    __fish_config_op_enabled $parts[1] $parts[2]
    check "$parts[1]: unset -> disabled" 1 $status

    set -g __fish_config_opinionated 1
    __fish_config_op_enabled $parts[1] $parts[2]
    check "$parts[1]: master truthy cannot enable" 1 $status

    set -g __fish_config_opinionated 0
    __fish_config_op_enabled $parts[1] $parts[2]
    check "$parts[1]: master off -> disabled" 1 $status

    reset_c5
    set -g __fish_config_op_logging garbage
    __fish_config_op_enabled $parts[1] $parts[2] 2>/dev/null
    check "$parts[1]: unrecognized value -> disabled" 1 $status

    reset_c5
    set -g __fish_config_op_logging 0
    __fish_config_op_enabled $parts[1] $parts[2]
    check "$parts[1]: explicit 0 -> disabled" 1 $status

    reset_c5
    set -g __fish_config_op_logging 1
    __fish_config_op_enabled $parts[1] $parts[2]
    check "$parts[1]: explicit truthy -> enabled" 0 $status

    set -g __fish_config_opinionated 0
    __fish_config_op_enabled $parts[1] $parts[2]
    check "$parts[1]: explicit truthy beats master off" 0 $status
end
reset_c5

# Fake tmux: records what the C5 consumers ask of it.
set -g tmux_calls
function tmux
    set -ga tmux_calls (string join ' ' -- $argv)
    switch "$argv[1]"
        case display-message
            if test "$argv[3]" = '#{session_name}'
                echo sess
            else
                echo w0-p0
            end
    end
end

section "C5: __fish_config_sync_logging when disabled"

# __fish_config_sync_logging also sources conf.d/pkg-wrappers.fish from the
# read-only $__fish_config_dir. That file returns immediately in a
# non-interactive shell, and HOME is the sandbox, so no wrapper is written.
# The sourced file's early `return` (1 when non-interactive) must not leak
# out: the function documents exit status 0 always (issue #290).
set -g sentinel $XDG_CONFIG_HOME/fish/.logging_disabled
set -gx SCROLLBACK_HISTORY_DIR $sandbox/logs
set -gx TMUX fake
reset_c5
set tmux_calls

__fish_config_sync_logging
check "unset: exits 0 (documented)" 0 $status
check "unset: sentinel created" true (yesno test -f $sentinel)
check "unset: tmux pipe-pane stopped (bare pipe-pane)" pipe-pane (string join , $tmux_calls)
check "unset: no log directory created" false (yesno test -e $SCROLLBACK_HISTORY_DIR)

set -g __fish_config_opinionated 1
set tmux_calls
__fish_config_sync_logging
check "master truthy: sentinel still present" true (yesno test -f $sentinel)
check "master truthy: no log capture started" false (yesno test -e $SCROLLBACK_HISTORY_DIR)

reset_c5
set -g __fish_config_op_logging garbage
set tmux_calls
__fish_config_sync_logging 2>/dev/null
check "unrecognized: sentinel present" true (yesno test -f $sentinel)
check "unrecognized: no log capture started" false (yesno test -e $SCROLLBACK_HISTORY_DIR)

section "C5: __fish_config_sync_logging when enabled"

reset_c5
set -g __fish_config_op_logging 1
set tmux_calls
__fish_config_sync_logging
check "explicit truthy: exits 0 (documented)" 0 $status
check "explicit truthy: sentinel removed" false (yesno test -e $sentinel)
check "explicit truthy: tmux capture started" true (yesno string match -q '*pipe-pane umask 077; cat >>*' -- (string join ' ' $tmux_calls))
check "explicit truthy: log directory created" true (yesno test -d $SCROLLBACK_HISTORY_DIR)

section "C5: toggling back off restores the sentinel"

set -g __fish_config_op_logging 0
set tmux_calls
__fish_config_sync_logging
check "explicit 0 after enabled: sentinel recreated" true (yesno test -f $sentinel)
check "explicit 0 after enabled: capture stopped" pipe-pane (string join , $tmux_calls)

section "C5: sync outside tmux issues no tmux calls"

set -e TMUX
reset_c5
set tmux_calls
__fish_config_sync_logging
check "disabled, no \$TMUX: no tmux calls" 0 (count $tmux_calls)
set -g __fish_config_op_logging 1
__fish_config_sync_logging
check "enabled, no \$TMUX: no tmux calls" 0 (count $tmux_calls)
check "enabled, no \$TMUX: sentinel removed" false (yesno test -e $sentinel)
functions -e tmux
reset_c5

section "C5: _zellij_dump_log is opt-in"

set -g zellij_calls 0
function zellij
    set -g zellij_calls (math $zellij_calls + 1)
    echo "pane contents"
end
set -gx ZELLIJ 0
set -gx ZELLIJ_SESSION_NAME sess
set -gx ZELLIJ_PANE_ID 1
set -gx SCROLLBACK_HISTORY_DIR $sandbox/zlogs

_zellij_dump_log
check "unset: exits 0" 0 $status
check "unset: zellij never invoked" 0 $zellij_calls
check "unset: no log directory" false (yesno test -e $SCROLLBACK_HISTORY_DIR)

set -g __fish_config_opinionated 1
_zellij_dump_log
check "master truthy: zellij never invoked" 0 $zellij_calls
check "master truthy: no log directory" false (yesno test -e $SCROLLBACK_HISTORY_DIR)

set -g __fish_config_opinionated 0
set -g __fish_config_op_logging 0
_zellij_dump_log
check "explicit 0: zellij never invoked" 0 $zellij_calls

reset_c5
set -g __fish_config_op_logging garbage
_zellij_dump_log 2>/dev/null
check "unrecognized: zellij never invoked" 0 $zellij_calls
check "unrecognized: no log directory" false (yesno test -e $SCROLLBACK_HISTORY_DIR)

reset_c5
set -g __fish_config_op_logging 1
_zellij_dump_log
check "explicit truthy: zellij invoked" 1 $zellij_calls
check "explicit truthy: one log written" 1 (count $SCROLLBACK_HISTORY_DIR/zellij_*.log)

functions -e zellij
set -e ZELLIJ ZELLIJ_SESSION_NAME ZELLIJ_PANE_ID SCROLLBACK_HISTORY_DIR
reset_c5

#   ─────────────────────────── _prune_terminal_logs ───────────────────────────

section "_prune_terminal_logs: scope of deletion"

# Five tmux logs plus decoys that must never be removed: another prefix, a
# non-.log file, an unrelated log, a name that merely ends in the prefix, and
# same-named files outside the log directory.
set -l d $sandbox/prune
command mkdir -p $d $sandbox/elsewhere
for i in 1 2 3 4 5
    touch -d "@"(math 1700000000 + $i) $d/tmux_$i.log
end
touch -d @1600000000 $d/zellij_1.log $d/tmux_notes.txt $d/other.log $d/xtmux_1.log
touch -d @1600000000 $sandbox/elsewhere/tmux_1.log $sandbox/tmux_1.log
set -gx SCROLLBACK_HISTORY_DIR $d
set -gx SCROLLBACK_HISTORY_MAX_FILES 2

_prune_terminal_logs tmux
check "exits 0" 0 $status
check "keeps exactly the newest 2 tmux logs" "tmux_4.log tmux_5.log" (string join ' ' $d/tmux_*.log | string replace -a "$d/" '')
check "other prefix untouched" true (yesno test -f $d/zellij_1.log)
check "non-.log file untouched" true (yesno test -f $d/tmux_notes.txt)
check "unrelated .log untouched" true (yesno test -f $d/other.log)
check "prefix match is anchored (xtmux_1.log kept)" true (yesno test -f $d/xtmux_1.log)
check "file in a sibling directory untouched" true (yesno test -f $sandbox/elsewhere/tmux_1.log)
check "file in the parent directory untouched" true (yesno test -f $sandbox/tmux_1.log)

section "_prune_terminal_logs: boundaries"

set -l d $sandbox/prune2
command mkdir -p $d
set -gx SCROLLBACK_HISTORY_DIR $d
for i in 1 2 3
    touch -d "@"(math 1700000000 + $i) $d/tmux_$i.log
end

set -gx SCROLLBACK_HISTORY_MAX_FILES 3
_prune_terminal_logs tmux
check "count == max: nothing pruned" 3 (count $d/tmux_*.log)
set -gx SCROLLBACK_HISTORY_MAX_FILES 5
_prune_terminal_logs tmux
check "count < max: nothing pruned" 3 (count $d/tmux_*.log)
set -gx SCROLLBACK_HISTORY_MAX_FILES 2
_prune_terminal_logs tmux
check "count == max+1: exactly one removed" 2 (count $d/tmux_*.log)
check "count == max+1: the oldest went" "tmux_2.log tmux_3.log" (string join ' ' (command ls -1 $d))
set -gx SCROLLBACK_HISTORY_MAX_FILES 1
_prune_terminal_logs tmux
check "max 1 keeps only the newest" tmux_3.log (command ls -1 $d)

# mtime, not name, decides which file is oldest.
set -l d $sandbox/prune3
command mkdir -p $d
set -gx SCROLLBACK_HISTORY_DIR $d
touch -d @1700000001 $d/tmux_zzz.log
touch -d @1700000002 $d/tmux_aaa.log
set -gx SCROLLBACK_HISTORY_MAX_FILES 1
_prune_terminal_logs tmux
check "sorted by mtime, not name" tmux_aaa.log (command ls -1 $d)

section "_prune_terminal_logs: default limit and odd inputs"

set -l d $sandbox/prune4
command mkdir -p $d
set -gx SCROLLBACK_HISTORY_DIR $d
for i in (seq 1 103)
    touch -d "@"(math 1700000000 + $i) $d/tmux_$i.log
end
set -e SCROLLBACK_HISTORY_MAX_FILES
_prune_terminal_logs tmux
check "default limit is 100" 100 (count $d/tmux_*.log)
check "default limit removed the 3 oldest" false (yesno test -e $d/tmux_3.log)
check "default limit kept the 4th oldest" true (yesno test -e $d/tmux_4.log)

set -gx SCROLLBACK_HISTORY_MAX_FILES 1
set -gx SCROLLBACK_HISTORY_DIR $sandbox/does-not-exist
_prune_terminal_logs tmux
check "missing log dir: exits 0" 0 $status
check "missing log dir: not created" false (yesno test -e $SCROLLBACK_HISTORY_DIR)

set -l d $sandbox/prune5
command mkdir -p $d
set -gx SCROLLBACK_HISTORY_DIR $d
_prune_terminal_logs tmux
check "empty log dir: exits 0" 0 $status
touch -d @1700000001 $d/tmux_1.log
touch -d @1700000002 $d/tmux_2.log
_prune_terminal_logs
check "no prefix argument: exits 0" 0 $status
check "no prefix argument: nothing removed" 2 (count $d/tmux_*.log)
_prune_terminal_logs nosuchprefix
check "prefix with no matches: nothing removed" 2 (count $d/tmux_*.log)

# A prefix containing a glob metacharacter must not widen the match.
touch $d/zellij_1.log $d/zellij_2.log
set -gx SCROLLBACK_HISTORY_MAX_FILES 0
_prune_terminal_logs 'z*'
check "glob metacharacter in prefix: exits 0" 0 $status
check "glob metacharacter in prefix: the tmux logs remain" 2 (count $d/tmux_*.log)

# The default directory is $HOME/.terminal_history -- the sandbox HOME here.
set -e SCROLLBACK_HISTORY_DIR
command mkdir -p $HOME/.terminal_history
touch -d @1700000001 $HOME/.terminal_history/tmux_1.log
touch -d @1700000002 $HOME/.terminal_history/tmux_2.log
set -gx SCROLLBACK_HISTORY_MAX_FILES 1
_prune_terminal_logs tmux
check "default dir is \$HOME/.terminal_history" tmux_2.log (command ls -1 $HOME/.terminal_history)
set -e SCROLLBACK_HISTORY_MAX_FILES

#   ─────────────────────────────── cleanup ───────────────────────────────
cd $real_cwd
for d in $TMPDIRS
    test -n "$d"; and command rm -rf -- $d
end

report
