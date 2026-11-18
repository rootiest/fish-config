#!/usr/bin/env fish
# Copyright (C) 2026 Rootiest
# SPDX-License-Identifier: AGPL-3.0-or-later
#
# detach: its own options come before the command; everything from the
# command's name on is forwarded to nohup untouched (issue #373).
#
# A stub nohup on PATH records its arguments instead of running anything.
#
# MODE: isolated

source (realpath (dirname (status filename)))/lib.fish
set -p fish_function_path $repo_root/functions
set -gx TERM xterm-256color

set -l tmp (mktemp -d)
set -l log $tmp/nohup.args
printf '%s\n' '#!/bin/sh' 'printf "%s\n" "$@" >"$NOHUP_LOG.tmp" && mv "$NOHUP_LOG.tmp" "$NOHUP_LOG"' >$tmp/nohup
chmod +x $tmp/nohup
set -gx PATH $tmp $PATH
set -gx NOHUP_LOG $log

# Runs detach, then waits (briefly) for the backgrounded stub to report what
# it was given. Prints the forwarded arguments, one per line.
function _detached_args --argument-names log
    rm -f $log
    detach $argv[2..] >/dev/null 2>&1
    for i in (seq 50)
        test -f $log; and break
        command sleep 0.05
    end
    test -f $log; and command cat $log
end

section "detach forwards the command's own options"

set -l got (_detached_args $log ls -la /tmp)
check "detach ls -la forwards -la" "ls -la /tmp" "$got"

set -l got (_detached_args $log some-app --version)
check "a --version after the command goes to the command" "some-app --version" "$got"

set -l got (_detached_args $log some-app --help)
check "a --help after the command goes to the command" "some-app --help" "$got"

set -l got (_detached_args $log -- -dash-named arg)
check "-- ends detach's options" "-dash-named arg" "$got"

section "detach's own options"

detach --help >/dev/null 2>&1
check "detach --help exits 0" 0 $status
set -l out (detach --help 2>/dev/null | string collect)
check "detach --help prints usage" true (string match -q '*Usage:*' -- $out; and echo true; or echo false)

detach --version >/dev/null 2>&1
check "detach --version exits 0" 0 $status

detach --bogus ls >/dev/null 2>&1
check "an unknown option before the command exits 2" 2 $status
set -l err (detach --bogus ls 2>&1 >/dev/null | string collect)
check "the unknown-option error goes to stderr" true (string match -q '*--bogus*' -- $err; and echo true; or echo false)

detach >/dev/null 2>&1
check "no command exits 2" 2 $status
detach -- >/dev/null 2>&1
check "only -- exits 2" 2 $status

rm -rf $tmp
report
