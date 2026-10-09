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
# The issue #250 retry tests need real universal variables (the pending marker
# is erased with `set -Ue`, which only works on a true universal), and
# `fish --no-config` disables those. So the child runs WITHOUT --no-config but
# fully sandboxed: HOME, XDG_CONFIG_HOME (hence fish_variables and config) and
# XDG_DATA_DIRS are throwaway, and fish_function_path is pinned to this repo plus
# fish's own functions so a distro-vendored `fisher` cannot leak in.
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

# nlines TEXT: number of non-blank lines in TEXT.
function nlines
    count (string match -r '\S' -- (string split \n -- $argv[1]))
end

# run_first_run MODE [extra env VAR=val ...]
# Sets: fr_out, fr_err (child stdout/stderr), fr_curl_log, fr_fisher_log,
# fr_status, fr_pending (the pending marker after the run, "unset" when absent)
# and fr_complete (same, for the first-run flag).
#
# Optional globals, reset by the caller between runs (see run_retry):
#   fr_pre    fish code run in the child before conf.d/first_run.fish
#   fr_post   fish code run in the child after it
#   fr_iflag  set (to nothing) for a non-interactive child; unset means -i
function run_first_run --inherit-variable sandbox --inherit-variable stub_bin --inherit-variable repo_root
    set -l mode $argv[1]
    set -l extra $argv[2..-1]
    set -l tag (random)
    set -l iflag -i
    set -q fr_iflag; and set iflag
    set -l pre true
    set -l post true
    set -q fr_pre; and set pre $fr_pre
    set -q fr_post; and set post $fr_post
    set -g fr_curl_log $sandbox/curl-$tag.log
    set -g fr_fisher_log $sandbox/fisher-$tag.log
    # Fresh universal-variable file per run so the first-run flag starts unset.
    command rm -rf $sandbox/cfg $sandbox/home $sandbox/state.txt
    mkdir -p $sandbox/cfg $sandbox/home
    set -l state_cmd "begin; set -q __fish_config_bootstrap_pending; and echo pending=\$__fish_config_bootstrap_pending; or echo pending=unset; set -q __fish_config_first_run_complete; and echo complete=\$__fish_config_first_run_complete; or echo complete=unset; end >$sandbox/state.txt"
    set -l script "set fish_function_path $repo_root/functions \$__fish_data_dir/functions; source $repo_root/conf.d/__fish_config_op_registry.fish; $pre; source $repo_root/conf.d/first_run.fish; $post; $state_cmd"
    env HOME=$sandbox/home XDG_CONFIG_HOME=$sandbox/cfg XDG_DATA_HOME=$sandbox/data XDG_DATA_DIRS=$sandbox/data \
        PATH="$stub_bin:$PATH" TERM=xterm CURL_STUB_MODE=$mode \
        CURL_STUB_LOG=$fr_curl_log FISHER_STUB_LOG=$fr_fisher_log $extra \
        fish $iflag -c $script >$sandbox/out.txt 2>$sandbox/err.txt
    set -g fr_status $status
    set -g fr_out (string collect <$sandbox/out.txt)
    set -g fr_err (string collect <$sandbox/err.txt)
    set -g fr_pending (string replace pending= '' (string match 'pending=*' <$sandbox/state.txt))
    set -g fr_complete (string replace complete= '' (string match 'complete=*' <$sandbox/state.txt))
    touch $fr_curl_log $fr_fisher_log
end

# run_retry PENDING MODE [extra env ...]
# A later start of an already-initialised shell whose bootstrap is pending:
# the first-run flag and the marker (PENDING, or "none" for no marker) are
# seeded as universal variables before conf.d/first_run.fish runs.
function run_retry
    set -l pending $argv[1]
    set -l rest $argv[2..-1]
    set -g fr_pre "set -U __fish_config_first_run_complete 1"
    test "$pending" != none; and set -g fr_pre "$fr_pre; set -U __fish_config_bootstrap_pending $pending"
    run_first_run $rest
    set -e fr_pre
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

section "first-run: a failed bootstrap leaves a pending marker (issue #250)"

set -l t_before (date +%s)
for mode in fail http-error empty garbage
    run_first_run $mode
    check "$mode: pending marker holds an epoch time" true (string match -qr '^[0-9]+$' -- $fr_pending; and test "$fr_pending" -ge $t_before; and echo true; or echo false)
    check "$mode: first-run flag still set" 1 $fr_complete
end
run_first_run good FISHER_STUB_FAIL=1
check "update fails: pending marker set" true (string match -qr '^[0-9]+$' -- $fr_pending; and echo true; or echo false)
check "update fails: first-run flag still set" 1 $fr_complete
run_first_run good
check "good: no pending marker" unset $fr_pending
check "good: first-run flag set" 1 $fr_complete

section "first-run: pending marker younger than 24h is not retried"

set -l now (date +%s)
run_retry (math $now - 3600) good
check "fresh marker: curl never called" "" (string collect <$fr_curl_log)
check "fresh marker: marker kept unchanged" (math $now - 3600) $fr_pending
check "fresh marker: one-line hint on stderr" 1 (nlines $fr_err)
check "fresh marker: hint mentions pending" true (string match -q '*bootstrap is pending*' -- $fr_err; and echo true; or echo false)
check "fresh marker: nothing on stdout" "" "$fr_out"

section "first-run: pending marker older than 24h is retried, bootstrap only"

set now (date +%s)
run_retry (math $now - 90000) good
check "stale marker: curl called once" 1 (nlines (string collect <$fr_curl_log))
check "stale marker: short --max-time on the retry" true (string match -q -- '*--max-time 10*' -- (string collect <$fr_curl_log); and echo true; or echo false)
check "stale marker: short --connect-timeout on the retry" true (string match -q -- '*--connect-timeout 3*' -- (string collect <$fr_curl_log); and echo true; or echo false)
check "stale marker: fisher update ran" "fisher-ran update" (string trim (string collect <$fr_fisher_log))
check "retry success: marker erased" unset $fr_pending
check "retry success: first-run flag untouched" 1 $fr_complete
check "retry success: one-line confirmation" true (string match -q '*bootstrap retry succeeded*' -- $fr_out; and echo true; or echo false)
check "retry success: exactly one stdout line" 1 (nlines $fr_out)
check "retry success: no welcome banner" false (string match -q '*Welcome*' -- $fr_out; and echo true; or echo false)
check "retry success: no Installing/Installed chatter" false (string match -q '*Fisher install*' -- $fr_out; and echo true; or echo false)
check "retry success: nothing on stderr" "" "$fr_err"

set now (date +%s)
run_retry (math $now - 90000) good FISHER_STUB_FAIL=1
check "retry, update fails: marker kept" true (string match -qr '^[0-9]+$' -- $fr_pending; and echo true; or echo false)
check "retry, update fails: failure reported on stderr" true (string match -q '*retry failed*' -- $fr_err; and echo true; or echo false)

section "first-run: a failed retry refreshes the timestamp"

set now (date +%s)
run_retry (math $now - 90000) fail
check "retry failure: marker refreshed to now" true (test "$fr_pending" -ge $now; and echo true; or echo false)
check "retry failure: one-line failure message on stderr" 1 (nlines $fr_err)
check "retry failure: says retry failed" true (string match -q '*retry failed*' -- $fr_err; and echo true; or echo false)
check "retry failure: nothing on stdout" "" "$fr_out"
check "retry failure: first-run flag untouched" 1 $fr_complete

section "first-run: at most one retry per session"

set now (date +%s)
set -g fr_post "source $repo_root/conf.d/first_run.fish"
run_retry (math $now - 90000) fail
set -e fr_post
check "two sources in one session: curl called once" 1 (nlines (string collect <$fr_curl_log))

section "first-run: bad timestamps mean retry now"

for bad in abc 99999999999
    run_retry $bad good
    check "marker '$bad': retried" true (test -n (string collect <$fr_curl_log); and echo true; or echo false)
    check "marker '$bad': marker erased on success" unset $fr_pending
end

section "first-run: no retry where it must not run"

set now (date +%s)
set -g fr_iflag
run_retry (math $now - 90000) good
set -e fr_iflag
check "non-interactive: curl never called" "" (string collect <$fr_curl_log)
check "non-interactive: marker untouched" (math $now - 90000) $fr_pending
check "non-interactive: silent" "" "$fr_out$fr_err"

run_retry (math $now - 90000) good __fish_config_op_autoexec=0
check "autoexec off: curl never called" "" (string collect <$fr_curl_log)
check "autoexec off: silent" "" "$fr_out$fr_err"

run_retry none good
check "no marker: curl never called" "" (string collect <$fr_curl_log)
check "no marker: fisher never run" "" (string collect <$fr_fisher_log)
check "no marker: silent" "" "$fr_out$fr_err"
check "no marker: still no marker" unset $fr_pending

section "sponge_privacy: notice when sponge is expected but missing"

mkdir -p $sandbox/cfg/fish
printf '%s\n' jorgebucaran/fisher meaningful-ooo/sponge >$sandbox/cfg/fish/fish_plugins
set -l sp_err (env HOME=$sandbox/home XDG_CONFIG_HOME=$sandbox/cfg fish --no-config -i -c "source $repo_root/conf.d/sponge_privacy.fish" 2>&1 >/dev/null | string collect)
check "sponge listed but absent: stderr notice" true (string match -q '*history secret filtering is inactive*' -- $sp_err; and echo true; or echo false)

printf '%s\n' jorgebucaran/fisher >$sandbox/cfg/fish/fish_plugins
set sp_err (env HOME=$sandbox/home XDG_CONFIG_HOME=$sandbox/cfg fish --no-config -i -c "source $repo_root/conf.d/sponge_privacy.fish" 2>&1 >/dev/null | string collect)
check "sponge not in fish_plugins: silent" "" "$sp_err"

command rm -rf $sandbox
report
