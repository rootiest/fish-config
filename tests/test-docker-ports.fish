#!/usr/bin/env fish
# Copyright (C) 2026 Rootiest
# SPDX-License-Identifier: AGPL-3.0-or-later
#
# Coverage for ld (lazydocker on the active Docker context) and ports
# (sudo lsof TCP listeners): argument rejection, missing-dependency errors,
# the exact command each one hands off to, and exit-status propagation.
#
# Runs isolated (no `# MODE:` marker). docker, lazydocker, sudo and lsof are
# all fakes on a throwaway PATH that record their argv and exit with a chosen
# code, so nothing here talks to a Docker daemon or asks for a password.

source (realpath (dirname (status filename)))/lib.fish
set -p fish_function_path $repo_root/functions

set -l stubs (mktemp -d)
set -l log $stubs/calls.log

# Each fake appends "name argv..." (plus DOCKER_HOST for lazydocker) to the
# log and exits with $STUB_STATUS (default 0).
for bin in docker lazydocker sudo lsof
    printf '%s\n' '#!/bin/sh' \
        "echo \"$bin \$* DOCKER_HOST=\${DOCKER_HOST:-}\" >>'$log'" \
        "test \"$bin\" = docker && echo tcp://ctx.example:2375" \
        'exit ${STUB_STATUS:-0}' >$stubs/$bin
    chmod +x $stubs/$bin
end

# A PATH holding only the fakes plus the real `env` that ld execs through.
set -l only $stubs/only
command mkdir -p $only
ln -s (command -s env) $only/env
set -l real_path $PATH

section ld

set -gx PATH $stubs $real_path
ld extra >/dev/null 2>&1
check "ld rejects arguments with 2" 2 $status

command rm -f $log
ld >/dev/null 2>&1
check "ld exits 0 when lazydocker does" 0 $status
check "ld points lazydocker at the active context's host" \
    "lazydocker  DOCKER_HOST=tcp://ctx.example:2375" (string match 'lazydocker*' <$log)

STUB_STATUS=3 ld >/dev/null 2>&1
check "ld propagates a failing exit status" 3 $status

ln -s $stubs/docker $only/docker
set -gx PATH $only
set -l err (ld 2>&1 >/dev/null)
check "ld without lazydocker exits 1" 1 $status
check "ld names the missing lazydocker" "ld: lazydocker is not installed" "$err"

# functions/docker.fish defines a `docker` wrapper function, so the guard
# must look for the binary, not just the name (#315).
set -gx PATH $real_path
set -l nodocker $stubs/nodocker
command mkdir -p $nodocker
ln -s $stubs/lazydocker $nodocker/lazydocker
ln -s (command -s env) $nodocker/env
command rm -f $log
set -gx PATH $nodocker
set -l err (ld 2>&1 >/dev/null)
check "ld without docker exits 1" 1 $status
check "ld names the missing docker" "ld: docker is not installed" "$err"
check "ld without docker launches nothing" false (test -e $log; and echo true; or echo false)

section ports

set -gx PATH $stubs $real_path
ports extra >/dev/null 2>&1
check "ports rejects arguments with 2" 2 $status

command rm -f $log
ports >/dev/null 2>&1
check "ports exits 0 when lsof does" 0 $status
check "ports runs lsof for TCP listeners through sudo" \
    "sudo lsof -iTCP -sTCP:LISTEN -P -n DOCKER_HOST=" (command cat $log)

STUB_STATUS=1 ports >/dev/null 2>&1
check "ports propagates lsof's exit status" 1 $status

set -gx PATH $only
ports >/dev/null 2>&1
check "ports without lsof exits 1" 1 $status

set -gx PATH $real_path
command rm -rf $stubs

report
