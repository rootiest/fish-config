#!/usr/bin/env fish
# Copyright (C) 2026 Rootiest
# SPDX-License-Identifier: AGPL-3.0-or-later
#
# MODE: isolated
#
# conf.d/first_run.fish Fisher bootstrap: a failed download must take the
# failure branch (issue #220). The file is run in a child interactive fish with
# a throwaway HOME / XDG dirs and a stub `curl` first on PATH, so nothing here
# touches the network, the real HOME or the real universal variables.
#
# The stub honours `-o FILE` the way real curl does and is steered by
# $CURL_STUB_MODE:
#   fail        exit 7, no output           (connection refused / offline)
#   http-error  exit 22, no output          (curl -f on a 404)
#   empty       exit 0, empty file          (200 with an empty body)
#   garbage     exit 0, HTML in the file    (200 with a non-fish body)
#   good        exit 0, a stub `fisher` definition
#
# The stub `fisher` fails (stdout line + stderr line, exit 1) when
# FISHER_STUB_FAIL=1, to exercise the `fisher update` failure reporting.

source (realpath (dirname (status filename)))/lib.fish

set -l sandbox (mktemp -d)
set -l stub_bin $sandbox/bin
mkdir -p $stub_bin $sandbox/home $sandbox/cfg $sandbox/data

# printf, not echo: the heredoc-ish body must stay byte-exact.
printf '%s\n' \
    '#!/bin/sh' \
    'echo "$*" >>"$CURL_STUB_LOG"' \
    'out=""' \
    'while [ $# -gt 0 ]; do [ "$1" = -o ] && out="$2"; shift; done' \
    'case "$CURL_STUB_MODE" in' \
    '  fail) exit 7 ;;' \
    '  http-error) exit 22 ;;' \
    '  empty) : >"$out"; exit 0 ;;' \
    '  garbage) echo "<html><body>Not Found</body></html>" >"$out"; exit 0 ;;' \
    '  good) printf "%s\n" "function fisher" "    echo fisher-ran \$argv >>\$FISHER_STUB_LOG" "    if test \"\$FISHER_STUB_FAIL\" = 1" "        echo \"fisher: fetching bad/plugin\"" "        echo \"fisher: Invalid plugin name or host unavailable: bad/plugin\" >&2" "        return 1" "    end" "end" >"$out"; exit 0 ;;' \
    esac \
    'exit 99' >$stub_bin/curl
chmod +x $stub_bin/curl

# run_first_run MODE [extra env VAR=val ...]
# Sets: fr_out, fr_err (child stdout/stderr), fr_curl_log, fr_fisher_log, fr_status.
function run_first_run --inherit-variable sandbox --inherit-variable stub_bin --inherit-variable repo_root
    set -l mode $argv[1]
    set -l extra $argv[2..-1]
    set -l tag (random)
    set -g fr_curl_log $sandbox/curl-$tag.log
    set -g fr_fisher_log $sandbox/fisher-$tag.log
    # Fresh universal-variable file per run so the first-run flag starts unset.
    command rm -rf $sandbox/cfg $sandbox/home
    mkdir -p $sandbox/cfg $sandbox/home
    env HOME=$sandbox/home XDG_CONFIG_HOME=$sandbox/cfg XDG_DATA_HOME=$sandbox/data \
        PATH="$stub_bin:$PATH" TERM=xterm CURL_STUB_MODE=$mode \
        CURL_STUB_LOG=$fr_curl_log FISHER_STUB_LOG=$fr_fisher_log $extra \
        fish --no-config -i -c "set -p fish_function_path $repo_root/functions; source $repo_root/conf.d/__fish_config_op_registry.fish; source $repo_root/conf.d/first_run.fish" >$sandbox/out.txt 2>$sandbox/err.txt
    set -g fr_status $status
    set -g fr_out (string collect <$sandbox/out.txt)
    set -g fr_err (string collect <$sandbox/err.txt)
    touch $fr_curl_log $fr_fisher_log
end

section "first-run: preconditions"

check "stub curl is executable" true (test -x $stub_bin/curl; and echo true; or echo false)

section "first-run: failed download takes the failure branch"

for mode in fail http-error empty garbage
    run_first_run $mode
    check "$mode: no 'Fisher installed.'" false (string match -q '*Fisher installed.*' -- $fr_out; and echo true; or echo false)
    check "$mode: failure message on stderr" true (string match -q '*Fisher install failed*' -- $fr_err; and echo true; or echo false)
    check "$mode: failure message not on stdout" false (string match -q '*Fisher install failed*' -- $fr_out; and echo true; or echo false)
    check "$mode: fisher update was not run" "" (string collect <$fr_fisher_log)
end

section "first-run: good download takes the success branch"

run_first_run good
check "good: 'Fisher installed.' printed" true (string match -q '*Fisher installed.*' -- $fr_out; and echo true; or echo false)
check "good: no failure message" false (string match -q '*Fisher install failed*' -- $fr_err; and echo true; or echo false)
check "good: fisher update ran" "fisher-ran update" (string trim (string collect <$fr_fisher_log))

section "first-run: fisher update failure reports the real error (issue #249)"

run_first_run good FISHER_STUB_FAIL=1
check "update fails: generic message on stderr" true (string match -q "*Fisher update failed*fisher update*manually*" -- $fr_err; and echo true; or echo false)
check "update fails: exit code reported" true (string match -q "*Fisher update failed (exit 1)*" -- $fr_err; and echo true; or echo false)
check "update fails: Fisher's stderr line is shown" true (string match -q "*Invalid plugin name or host unavailable: bad/plugin*" -- $fr_err; and echo true; or echo false)
check "update fails: Fisher's stdout context is shown" true (string match -q "*fisher: fetching bad/plugin*" -- $fr_err; and echo true; or echo false)
check "update fails: nothing about it on stdout" false (string match -q "*Invalid plugin name*" -- $fr_out; and echo true; or echo false)
check "update fails: 'Fisher installed.' still printed" true (string match -q "*Fisher installed.*" -- $fr_out; and echo true; or echo false)

run_first_run good
check "update ok: no update failure text on stderr" false (string match -q "*Fisher update failed*" -- $fr_err; and echo true; or echo false)
check "update ok: no Fisher output on stderr" false (string match -q "*fisher: *" -- $fr_err; and echo true; or echo false)
check "update ok: no Fisher output leaked to stdout" false (string match -q "*fisher: *" -- $fr_out; and echo true; or echo false)

section "first-run: download is pinned and hardened"

set -l curl_args (string collect <$fr_curl_log)
check "fetches from a pinned ref, not main" true (string match -qr 'jorgebucaran/fisher/[0-9]+\.[0-9]+\.[0-9]+/functions/fisher\.fish' -- $curl_args; and echo true; or echo false)
check "does not use the floating main branch" false (string match -q '*fisher/main/*' -- $curl_args; and echo true; or echo false)
check "curl fails on HTTP errors (-f)" true (string match -qr -- '-\S*f\S*' -- $curl_args; and echo true; or echo false)
check "curl has a --max-time" true (string match -q -- '*--max-time*' -- $curl_args; and echo true; or echo false)

section "first-run: C2 guard still gates the bootstrap"

run_first_run good __fish_config_op_autoexec=0
check "autoexec off: curl never called" "" (string collect <$fr_curl_log)
check "autoexec off: no bootstrap output" false (string match -q '*Installing Fisher*' -- $fr_out; and echo true; or echo false)

section "sponge_privacy: notice when sponge is expected but missing"

mkdir -p $sandbox/cfg/fish
printf '%s\n' jorgebucaran/fisher@4.4.8 meaningful-ooo/sponge@1.1.0 >$sandbox/cfg/fish/fish_plugins
set -l sp_err (env HOME=$sandbox/home XDG_CONFIG_HOME=$sandbox/cfg fish --no-config -i -c "source $repo_root/conf.d/sponge_privacy.fish" 2>&1 >/dev/null | string collect)
check "sponge listed (pinned @ref) but absent: stderr notice" true (string match -q '*history secret filtering is inactive*' -- $sp_err; and echo true; or echo false)

printf '%s\n' jorgebucaran/fisher@4.4.8 >$sandbox/cfg/fish/fish_plugins
set sp_err (env HOME=$sandbox/home XDG_CONFIG_HOME=$sandbox/cfg fish --no-config -i -c "source $repo_root/conf.d/sponge_privacy.fish" 2>&1 >/dev/null | string collect)
check "sponge not in fish_plugins: silent" "" "$sp_err"

command rm -rf $sandbox
report
