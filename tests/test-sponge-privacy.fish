#!/usr/bin/env fish
# Copyright (C) 2026 Rootiest
# SPDX-License-Identifier: AGPL-3.0-or-later
#
# MODE: isolated
#
# conf.d/sponge_privacy.fish retired-pattern migration (issue #253). The file
# is sourced in a child interactive fish with a throwaway HOME / XDG dirs, so
# the universal sponge_regex_patterns it edits lives in a sandboxed
# fish_variables and never touches the real one.

source (realpath (dirname (status filename)))/lib.fish

set -l sandbox (mktemp -d)
mkdir -p $sandbox/home $sandbox/cfg $sandbox/data

# run_sponge SEED... : seed the universal list, load the file twice (the
# second load proves idempotence), then print the list one entry per line.
function run_sponge --inherit-variable sandbox --inherit-variable repo_root
    command rm -rf $sandbox/cfg $sandbox/home
    mkdir -p $sandbox/cfg $sandbox/home
    env HOME=$sandbox/home XDG_CONFIG_HOME=$sandbox/cfg XDG_DATA_HOME=$sandbox/data \
        TERM=xterm SEED=(string join \n -- $argv | string collect) \
        fish --no-config -i -c '
            set -g sponge_version stub
            set -U sponge_regex_patterns (string split \n -- $SEED)
            source '$repo_root'/conf.d/sponge_privacy.fish
            source '$repo_root'/conf.d/sponge_privacy.fish
            printf "%s\n" $sponge_regex_patterns' 2>/dev/null
end

set -l old_pat 'curl\s.*[Aa]uthorization:'
set -l mid_pat '(?i)curl\s.*authorization:'
set -l new_pat '(?i)\b(?:curl|wget|https?)\s.*(?:authorization|x-api-key|x-auth-token):'
set -l custom 'my-custom-[Aa]uthorization:'

section "sponge_privacy: retired patterns are migrated"

set -l got (run_sponge $old_pat $custom)
check "retired pattern removed" false (contains -- $old_pat $got; and echo true; or echo false)
check "replacement pattern registered" true (contains -- $new_pat $got; and echo true; or echo false)
check "user-added pattern preserved" true (contains -- $custom $got; and echo true; or echo false)
check "replacement registered exactly once (idempotent)" 1 (count (string match -- $new_pat $got))
check "custom pattern kept exactly once" 1 (count (string match -- $custom $got))

section "sponge_privacy: superseded curl-only pattern is migrated (#254)"

set got (run_sponge $mid_pat $custom)
check "curl-only pattern removed" false (contains -- $mid_pat $got; and echo true; or echo false)
check "broadened pattern registered" true (contains -- $new_pat $got; and echo true; or echo false)
check "user-added pattern preserved (#254)" true (contains -- $custom $got; and echo true; or echo false)

section "sponge_privacy: near-miss user patterns are not retired"

set -l near 'curl\s.*[Aa]uthorization:.*'
set got (run_sponge $near)
check "superstring of a retired pattern preserved" true (contains -- $near $got; and echo true; or echo false)

section "sponge_privacy: clean install"

set got (run_sponge placeholder)
check "no retired pattern on a fresh list" false (contains -- $old_pat $got; and echo true; or echo false)
check "replacement registered" true (contains -- $new_pat $got; and echo true; or echo false)

command rm -rf $sandbox
report
