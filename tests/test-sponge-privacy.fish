#!/usr/bin/env fish
# Copyright (C) 2026 Rootiest
# SPDX-License-Identifier: AGPL-3.0-or-later
#
# MODE: isolated
#
# conf.d/sponge_privacy.fish stale-pattern migrations (issues #253, #267, #312). The file
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

section "sponge_privacy: dash-led patterns are escaped (#312)"

# sponge_filter_matched runs `string match --regex --quiet $pattern -- $cmd`,
# so a pattern starting with `-` is parsed as an option and never matches.
set -l stale '--password=\S+'
set -l stale2 --token
set -l single '-p\s+\S+'
set -l custom2 'my-custom-token-\d+'
set got (run_sponge $stale $custom2 $stale2 $single)
check "stored -- entry escaped" true (contains -- '\-\-password=\S+' $got; and echo true; or echo false)
check "second stored -- entry escaped" true (contains -- '\-\-token' $got; and echo true; or echo false)
check "single-dash entry escaped" true (contains -- '\-p\s+\S+' $got; and echo true; or echo false)
check "custom pattern preserved beside dash-led entries" true (contains -- $custom2 $got; and echo true; or echo false)
check "custom pattern kept exactly once" 1 (count (string match -- $custom2 $got))
check "no entry left beginning with -" 0 (count (string match -- '-*' $got))
check "static pattern registered after the rewrite" true (contains -- $new_pat $got; and echo true; or echo false)

# Every stored pattern must survive sponge's own call order (pattern before
# the -- sentinel); the escaped single-dash one now catches its secret.
set -l errors
for p in $got
    string match --regex --quiet $p -- probe 2>/dev/null
    test $status -le 1; or set -a errors $p
end
check "no stored pattern is parsed as an option" "" "$errors"
check "escaped -p pattern matches in sponge's call order" 0 \
    (string match --regex --quiet '\-p\s+\S+' -- 'mysql -p hunter2'; echo $status)

# The pre-13eb93c `--(?:password|...)` form becomes the current static
# pattern, so it is not registered twice.
set -l legacy '--(?:password|passwd|passphrase|token|secret|api[-_]key)(?:\s+|=)\S+'
set got (run_sponge $legacy)
check "legacy -- pattern folds into the current one" 1 \
    (count (string match -- '\-\-(?:password|passwd|passphrase|token|secret|api[-_]key)(?:\s+|=)\S+' $got))

set got (run_sponge $stale $old_pat $custom2)
check "dash-led entry escaped and retired entry purged together" 0 (count (string match -- '-*' $got) (string match -- $old_pat $got))
check "custom preserved when both kinds handled" true (contains -- $custom2 $got; and echo true; or echo false)

set got (run_sponge 'a--b' $custom2)
check "-- in the middle of a user pattern is left alone" true (contains -- 'a--b' $got; and echo true; or echo false)

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
