#!/usr/bin/env fish
# Copyright (C) 2026 Rootiest
# SPDX-License-Identifier: AGPL-3.0-or-later
#
# MODE: isolated
#
# Startup-time budget (issue #237). Times an interactive start of a COPY of
# this config in a throwaway HOME/XDG tree and WARNS when the median is over
# a budget. It never fails the run: wall-clock time on a shared CI runner is
# too noisy to gate on, but a regression that doubles startup should be
# visible in the log. What IS asserted is the verdict logic itself, with
# synthetic numbers, so the warning cannot silently stop working.
#
# Why the budget lives in a suite and not in tests/run-tests.fish: the
# driver says suites are never special-cased by name, and this keeps the
# knob, the measurement and the verdict function in one file that can be
# read, run alone (`fish tests/test-startup-budget.fish`) or deleted.
#
# Tunables (environment):
#   FISH_CONFIG_STARTUP_BUDGET_MS    median budget in ms (default 200; CI
#                                    medians were 77-90 ms, no sample over
#                                    98 ms, when it was set in issue #335,
#                                    so the default trips on a regression
#                                    of roughly double that)
#   FISH_CONFIG_STARTUP_BUDGET_RUNS  timed starts per measurement (default 5,
#                                    median taken; one extra warm-up first)
#   FISH_CONFIG_STARTUP_BUDGET_SKIP  non-empty: do not measure at all
#
# The warm-up start runs with C2 auto-exec off so first-run never reaches for
# the network; the timed starts then run with the config exactly as shipped.

source (realpath (dirname (status filename)))/lib.fish

set -g budget_ms 200
set -q FISH_CONFIG_STARTUP_BUDGET_MS
and string match -qr '^[0-9]+$' -- $FISH_CONFIG_STARTUP_BUDGET_MS
and set budget_ms $FISH_CONFIG_STARTUP_BUDGET_MS
set -g budget_runs 5
set -q FISH_CONFIG_STARTUP_BUDGET_RUNS
and string match -qr '^[1-9][0-9]*$' -- $FISH_CONFIG_STARTUP_BUDGET_RUNS
and set budget_runs $FISH_CONFIG_STARTUP_BUDGET_RUNS

# Verdict for one measurement: prints ok or warn. A budget of 0 disables it.
function budget_verdict --argument-names median_ms limit_ms
    if test "$limit_ms" -le 0
        echo ok
    else if test "$median_ms" -gt "$limit_ms"
        echo warn
    else
        echo ok
    end
end

# Median of the integers in $argv.
function median_of
    set -l sorted (printf '%s\n' $argv | sort -n)
    echo $sorted[(math --scale=0 "floor((" (count $sorted) " + 1) / 2)")]
end

# Wall time in ms of one command, or nothing when %N is unsupported.
function time_ms
    set -l t0 (command date +%s%N)
    command $argv >/dev/null 2>&1
    set -l t1 (command date +%s%N)
    string match -qr '^\d{15,}$' -- $t0 $t1; or return 1
    math --scale=0 "($t1 - $t0) / 1000000"
end

section "startup budget: verdict logic"

check "under budget" ok (budget_verdict 120 500)
check "at budget" ok (budget_verdict 500 500)
check "over budget" warn (budget_verdict 501 500)
check "budget 0 disables" ok (budget_verdict 99999 0)
check "median of an odd count" 3 (median_of 9 1 3 7 2)
check "median of an even count (lower middle)" 2 (median_of 4 1 2 3)

section "startup budget: measurement"

if test -n "$FISH_CONFIG_STARTUP_BUDGET_SKIP"
    echo "  SKIP  startup budget (FISH_CONFIG_STARTUP_BUDGET_SKIP set)"
else if not test -f $repo_root/config.fish
    echo "  SKIP  startup budget (no config.fish under $repo_root)"
else
    set -l sandbox (mktemp -d)
    set -l cfg $sandbox/xdgcfg/fish
    command mkdir -p $cfg $sandbox/home/.local/bin $sandbox/cwd $sandbox/cache
    command cp $repo_root/config.fish $cfg/
    # Without sponge installed its notice would land on stderr.
    test -f $repo_root/fish_plugins
    and string match -v -- '*meaningful-ooo/sponge*' <$repo_root/fish_plugins >$cfg/fish_plugins
    for d in functions conf.d completions themes data
        test -d $repo_root/$d
        and command cp -r $repo_root/$d $cfg/
    end

    set -l fish_bin (status fish-path)
    # The fish_greeting stub keeps distro greeters (CachyOS runs fastfetch)
    # out of the number: they are not this config.
    set -l base_env HOME=$sandbox/home XDG_CONFIG_HOME=$sandbox/xdgcfg \
        XDG_CACHE_HOME=$sandbox/cache PATH=$PATH TERM=xterm
    set -l start $fish_bin -i -C 'function fish_greeting; end' -c exit

    pushd $sandbox/cwd
    command env -i $base_env __fish_config_op_autoexec=off $start >/dev/null 2>&1
    set -l samples
    set -l ok 1
    for i in (seq $budget_runs)
        set -l ms (time_ms env -i $base_env $start)
        or begin
            set ok 0
            break
        end
        set -a samples $ms
    end
    set -l bare (time_ms env -i HOME=$sandbox/home PATH=$PATH TERM=xterm $fish_bin --no-config -i -c exit)
    popd

    if test $ok -eq 0
        echo "  SKIP  startup budget (date +%s%N unsupported here)"
    else
        set -l med (median_of $samples)
        echo "  INFO  startup: median $med ms of $budget_runs (min "(printf '%s\n' $samples | sort -n | head -n1)", max "(printf '%s\n' $samples | sort -n | tail -n1)"); bare fish --no-config: $bare ms; budget $budget_ms ms"
        if test (budget_verdict $med $budget_ms) = warn
            echo "  WARN  startup median $med ms is over the $budget_ms ms budget (FISH_CONFIG_STARTUP_BUDGET_MS). Not a failure: timing is noisy; profile with `fish --profile-startup=/tmp/p.txt -i -c exit`." >&2
        end
    end
    command rm -rf $sandbox
end

report
