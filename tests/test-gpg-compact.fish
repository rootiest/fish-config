#!/usr/bin/env fish
# Copyright (C) 2026 Rootiest
# SPDX-License-Identifier: AGPL-3.0-or-later
#
# MODE: isolated
#
# functions/gpg-compact.fish (compact GPG key listing with card serials).
#
# Never touches a real keyring: every call runs in its own --no-config fish
# whose PATH starts with a fake `gpg` script. The fake records its arguments
# and prints a canned --with-colons listing, so the card, stub, revoked,
# expired, disabled and escaped-UID cases are all covered without a
# smartcard or a key. TZ is pinned to UTC so the dates are fixed.

source (realpath (dirname (status filename)))/lib.fish

set -g sb (mktemp -d)
or begin
    echo "  FAIL  cannot create sandbox"
    exit 1
end
mkdir -p $sb/bin $sb/nogpg

# The fake gpg: argv to $sb/args, fixture to stdout, exit $FAKE_GPG_RC.
printf '%s\n' \
    '#!/bin/sh' \
    'printf "%s\n" "$@" >"$FAKE_GPG_ARGS"' \
    'cat "$FAKE_GPG_FIXTURE"' \
    'exit "${FAKE_GPG_RC:-0}"' >$sb/bin/gpg
chmod +x $sb/bin/gpg

# Fields: 1 type, 2 validity, 3 length, 4 algo, 5 key ID, 6 created,
# 7 expires, 10 user ID, 12 capabilities, 15 card serial / "+" / "#",
# 17 curve.
printf '%s\n' \
    'sec:u:255:22:AAAAAAAA11111111:1700000000::::::scSC:::D2760001240103040006123456780000::ed25519:::0:' \
    'fpr:::::::::0000000000000000000000000000AAAAAAAA11111111:' \
    'uid:u::::1700000000::HASH::Alice \x3a Ops <alice@example.org>::::::::::0:' \
    'uid:r::::1700000000::HASH::Old \x5cx3a Name <old@example.org>::::::::::0:' \
    'ssb:u:255:18:BBBBBBBB22222222:1700000000:1800000000:::::e:::D2760001240103040006123456780000::cv25519:' \
    'ssb:e:4096:1:CCCCCCCC33333333:1600000000:1650000000:::::s:::#:::' \
    'sec:r:4096:1:DDDDDDDD44444444:1600000000::::::scESC:::+:::' \
    'uid:-::::1600000000::HASH::Bob\x07 <bob@example.org>::::::::::0:' \
    'sec:u:255:22:EEEEEEEE55555555:1700000000::::::cCD:::FFC1234567::ed25519:' >$sb/keys
printf '' >$sb/empty

# One run: status in $gc_rc, stdout lines in $gc_out, stderr in $gc_err,
# the fake's argv in $gc_args.
function gc
    set -l path $sb/bin $PATH
    set -q GC_NO_GPG; and set path $sb/nogpg
    rm -f $sb/args
    env PATH=(string join : $path) TZ=UTC FAKE_GPG_ARGS=$sb/args \
        FAKE_GPG_FIXTURE=$gc_fixture FAKE_GPG_RC=$gc_gpg_rc \
        (command -s fish) --no-config -c \
        "set -g fish_function_path $repo_root/functions \$fish_function_path; gpg-compact \$argv" \
        -- $argv </dev/null >$sb/out 2>$sb/err
    set -g gc_rc $status
    set -g gc_out (command cat $sb/out)
    set -g gc_err (string collect <$sb/err)
    set -g gc_args
    test -f $sb/args; and set -g gc_args (command cat $sb/args)
end

set -gx TERM dumb
set -gx NO_COLOR 1
set -g gc_fixture $sb/keys
set -g gc_gpg_rc 0

section "help and usage"

gc --help
check "--help exits 0" 0 $gc_rc
check "--help prints the header" true (string match -q '*USAGE*' -- $gc_out; and echo true; or echo false)
check "--help never runs gpg" '' "$gc_args"

gc -K -k
check "-K with -k is a usage error" 2 $gc_rc
check "-K with -k never runs gpg" '' "$gc_args"

gc --bogus
check "unknown option is a usage error" 2 $gc_rc

section "gpg invocation"

gc
check "default lists secret keys" --list-secret-keys $gc_args[4]
check "default passes no pattern" -- "$gc_args[-1]"

gc -k alice -- -dash
check "-k lists public keys" --list-keys $gc_args[4]
check "patterns reach gpg after --, so a dash pattern is not a gpg option" '-- alice -dash' "$gc_args[5..-1]"

section listing

gc
check "listing exits 0" 0 $gc_rc
set -l want \
    'sec>  ed25519/11111111 2023-11-14 [SC] [card:12345678]' \
    '      Alice : Ops <alice@example.org>' \
    '      Old \x3a Name <old@example.org> [revoked]' \
    '  ssb>  cv25519/22222222 2023-11-14 [E] [expires: 2027-01-15] [card:12345678]' \
    '  ssb#  rsa4096/33333333 2020-09-13 [S] [expired: 2022-04-15]' \
    '' \
    'sec   rsa4096/44444444 2020-09-13 [SC] [revoked]' \
    '      Bob\x07 <bob@example.org>' \
    '' \
    'sec>  ed25519/55555555 2023-11-14 [C] [disabled] [card:FFC1234567]' \
    ''
check "line count" (count $want) (count $gc_out)
for i in (seq (count $want))
    check "line $i" "$want[$i]" "$gc_out[$i]"
end

set -g gc_fixture $sb/empty
gc
check "empty keyring exits 0" 0 $gc_rc
check "empty keyring prints nothing" 0 (count $gc_out)
set -g gc_fixture $sb/keys

section colour

set -e NO_COLOR
set -gx TERM xterm-256color
gc
check "piped output carries no escape codes" false (string match -q '*'\e'*' -- $gc_out; and echo true; or echo false)
set -gx TERM dumb
set -gx NO_COLOR 1

section failures

set -g gc_gpg_rc 2
gc nosuchkey
check "gpg failure maps to 1" 1 $gc_rc
set -g gc_gpg_rc 0

set -gx GC_NO_GPG 1
gc
check "missing gpg exits 1" 1 $gc_rc
check "missing gpg says so on stderr" true (string match -q '*gpg is not installed*' -- $gc_err; and echo true; or echo false)
set -e GC_NO_GPG

rm -rf $sb
report
