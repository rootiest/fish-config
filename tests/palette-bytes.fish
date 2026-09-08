#!/usr/bin/env fish
# Copyright (C) 2026 Rootiest
# SPDX-License-Identifier: AGPL-3.0-or-later
#
# Byte-identity harness for the shared output palette (__fish_palette).
#
# Compares rendered output of every colour-bearing function between a
# pristine checkout of a baseline git ref and the current working tree.
# This is a one-time acceptance harness, not part of run-tests.fish's
# permanent suite -- the permanent check lives in tests/functional.fish.
#
# Usage:
#   fish tests/palette-bytes.fish [--baseline REF]   byte-diff stdout+stderr
#   fish tests/palette-bytes.fish --structural       diff-shape assertion
#   fish tests/palette-bytes.fish --startup          startup medians
#
# Both sandboxes get an isolated XDG_CONFIG_HOME carrying a copy of the
# working tree's fish_variables. That file is gitignored, so `git archive`
# omits it; without it __fish_config_op_enabled is unresolvable and every
# opinionated-guarded function silently short-circuits.

set -l repo (realpath (dirname (status filename))/..)
set -l mode bytes
set -l baseline main
for i in (seq (count $argv))
    switch $argv[$i]
        case --structural; set mode structural
        case --startup; set mode startup
        case --baseline; set baseline $argv[(math $i + 1)]
    end
end

set -l tmp (mktemp -d)
function __pb_cleanup --on-event fish_exit --inherit-variable tmp
    test -n "$tmp"; and rm -rf $tmp
end

# ── Build the two sandboxes ────────────────────────────────────────────
set -l A $tmp/base/fish   # pristine baseline ref
set -l B $tmp/work/fish   # current working tree
mkdir -p $A $B
git -C $repo archive $baseline | tar -x -C $A
or begin
    echo "palette-bytes: cannot archive baseline ref '$baseline'" >&2
    exit 2
end
for d in functions conf.d completions integrations themes data
    test -d $repo/$d; and cp -r $repo/$d $B/
end
cp $repo/config.fish $B/ 2>/dev/null
# fish_variables is gitignored -- copy it into BOTH sandboxes by hand.
for d in $A $B
    cp $repo/fish_variables $d/ 2>/dev/null
end
# qc --help shells out to aichat; stub it so its colour path is reachable.
set -l stub $tmp/stub
mkdir -p $stub
printf '#!/bin/sh\necho "aichat stub"\n' >$stub/aichat
chmod +x $stub/aichat

# ── The cases ──────────────────────────────────────────────────────────
# 25 --help paths (every converted function that has one) plus 4 error
# paths, two of which write to stderr. Side-effect-free by construction:
# --help returns before doing work, and each error path fails on argument
# validation. Do NOT add a case that mutates the filesystem.
set -l cases \
    "agents-init --help" "agents-vault --help" "auto-pull --help" \
    "config-settings --help" "config-update --help" "detach --help" \
    "dng2avif --help" "dockup --help" "edit --help" "jobrunner --help" \
    "kitty-logging --help" "logs --help" "mkcd --help" "open-url --help" \
    "p --help" "pkg --help" "play-media --help" "qc --help" \
    "rand_string --help" "replay --help" "repo-open --help" "scrub --help" \
    "smart_exit --help" "spark --help" "y --help" \
    "mkcd" "auto-pull remove __no_such_repo__" \
    "agents-init --no-such-flag" "pkg __no_such_subcommand__"

function __pb_run --argument-names cfg stub cmd out
    env XDG_CONFIG_HOME=(dirname $cfg) PATH="$stub:$PATH" TERM=xterm-256color \
        HOME=$HOME fish -c "$cmd" >$out.out 2>$out.err
end

# ── Mode: bytes ────────────────────────────────────────────────────────
if test $mode = bytes
    echo "== palette byte-identity vs $baseline =="
    set -l failed 0
    set -l n 0
    for cmd in $cases
        set n (math $n + 1)
        __pb_run $A $stub "$cmd" $tmp/a$n
        __pb_run $B $stub "$cmd" $tmp/b$n
        set -l so ok
        set -l se ok
        cmp -s $tmp/a$n.out $tmp/b$n.out; or set so DIFF
        cmp -s $tmp/a$n.err $tmp/b$n.err; or set se DIFF
        if test $so = DIFF -o $se = DIFF
            set failed (math $failed + 1)
            printf '  FAIL  %-34s stdout=%s stderr=%s\n' "$cmd" $so $se
            test $so = DIFF; and diff -u (xxd $tmp/a$n.out | psub) (xxd $tmp/b$n.out | psub) | head -12
            test $se = DIFF; and diff -u (xxd $tmp/a$n.err | psub) (xxd $tmp/b$n.err | psub) | head -12
        else
            printf '  ok    %-34s (%s B out, %s B err)\n' "$cmd" (wc -c <$tmp/a$n.out | string trim) (wc -c <$tmp/a$n.err | string trim)
        end
    end
    echo (math $n - $failed)"/$n cases byte-identical"
    test $failed -eq 0
    exit $status
end

# ── Mode: structural ───────────────────────────────────────────────────
# For files converted WITHOUT drift renames, the whole diff must be
# declaration removals plus inserted __fish_palette calls. If that holds,
# the file's output strings are provably untouched.
if test $mode = structural
    echo "== structural diff shape vs $baseline =="
    set -l bad 0
    for f in (git -C $repo diff --name-only $baseline -- functions/)
        # fish_prompt.fish keeps its own hex palette -- see Task 10.
        string match -q '*fish_prompt.fish' $f; and continue
        # __fish_palette.fish is the palette itself: a new file, so its diff
        # is 100% additions and can never be "purely structural". Skipping it
        # is not a loosening -- it declares the colours rather than rendering
        # any, and tests/functional.fish asserts its 12 roles directly.
        string match -q '*__fish_palette.fish' $f; and continue
        set -l offenders
        for line in (git -C $repo diff -U0 $baseline -- $f | string match -r '^[+-][^+-].*')
            set -l body (string sub -s 2 -- $line)
            string match -qr '^\s*set -l c_[a-z]+\s+\(set_color[^)]*\)\s*$' -- $body; and continue
            string match -qr '^\s*__fish_palette\s*$' -- $body; and continue
            set -a offenders $line
        end
        if test (count $offenders) -gt 0
            set bad (math $bad + 1)
            echo "  NOT PURELY STRUCTURAL  $f"
            printf '      %s\n' $offenders[1..3]
        end
    end
    if test $bad -eq 0
        echo "  all changed files are purely structural"
    else
        echo "  $bad file(s) changed rendering text -- expected only for the drift-rename batch"
    end
    test $bad -eq 0
    exit $status
end

# ── Mode: startup ──────────────────────────────────────────────────────
echo "== fish -c true, 31 interleaved pairs, median =="
set -l ta
set -l tb
for i in (seq 31)
    set -l s (date +%s%N)
    env XDG_CONFIG_HOME=$tmp/base fish -c true >/dev/null 2>&1
    set -a ta (math "("(date +%s%N)" - $s) / 1000")
    set s (date +%s%N)
    env XDG_CONFIG_HOME=$tmp/work fish -c true >/dev/null 2>&1
    set -a tb (math "("(date +%s%N)" - $s) / 1000")
end
set -l sa (printf '%s\n' $ta | sort -n)
set -l sb (printf '%s\n' $tb | sort -n)
printf '  baseline  median=%.2f ms  p10=%.2f  p90=%.2f\n' (math $sa[16]/1000) (math $sa[4]/1000) (math $sa[28]/1000)
printf '  working   median=%.2f ms  p10=%.2f  p90=%.2f\n' (math $sb[16]/1000) (math $sb[4]/1000) (math $sb[28]/1000)
echo "  (p10-p90 spread is ~15 ms; treat any delta inside it as noise)"
