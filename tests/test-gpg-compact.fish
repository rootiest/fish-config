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
mkdir -p $sb/bin $sb/agentbin $sb/tools $sb/nogpg

# PATH holds only sandbox dirs, so the real gpg and gpg-connect-agent can
# never be reached. $sb/tools links the few real binaries the function and
# the help renderer need.
for tool in awk cat timeout
    ln -s (command -s $tool) $sb/tools/$tool
end

# The fake gpg: argv to $FAKE_GPG_ARGS, fixture to stdout, exit $FAKE_GPG_RC.
printf '%s\n' \
    '#!/bin/sh' \
    'printf "%s\n" "$@" >"$FAKE_GPG_ARGS"' \
    'cat "$FAKE_GPG_FIXTURE"' \
    'exit "${FAKE_GPG_RC:-0}"' >$sb/bin/gpg
# The fake agent: reports one connected card, and leaves a marker so a test
# can tell whether it was asked at all.
printf '%s\n' \
    '#!/bin/sh' \
    'printf "%s\n" "$@" >"$FAKE_AGENT_ARGS"' \
    'echo "S SERIALNO D2760001240103040006123456780000"' \
    'echo OK' \
    'echo "ERR 67108924 Not supported <GPG Agent>"' >$sb/agentbin/gpg-connect-agent
chmod +x $sb/bin/gpg $sb/agentbin/gpg-connect-agent

# Fields: 1 type, 2 validity, 3 length, 4 algo, 5 key ID, 6 created,
# 7 expires, 10 user ID or fingerprint, 12 capabilities, 15 card serial /
# "+" / "#", 17 curve.
printf '%s\n' \
    'sec:u:255:22:AAAAAAAA11111111:1700000000::::::scSC:::D2760001240103040006123456780000::ed25519:::0:' \
    'fpr:::::::::0000000000000000000000000000AAAAAAAA11111111:' \
    'grp:::::::::5DD19DE2E1C51C0A5345C7B2D469DB295B4251E5:' \
    'uid:u::::1700000000::HASH::Alice \x3a Ops <alice@example.org>::::::::::0:' \
    'uid:r::::1700000000::HASH::Old \x5cx3a Name <old@example.org>::::::::::0:' \
    'ssb:u:255:18:BBBBBBBB22222222:1700000000:1800000000:::::e:::D2760001240103040006123456780000::cv25519:' \
    'fpr:::::::::1111111111111111111111111111BBBBBBBB22222222:' \
    'ssb:e:4096:1:CCCCCCCC33333333:1600000000:1650000000:::::s:::#:::' \
    'sec:r:4096:1:DDDDDDDD44444444:1600000000::::::scESC:::+:::' \
    'fpr:::::::::2222222222222222222222222222DDDDDDDD44444444:' \
    'uid:-::::1600000000::HASH::Bob\x07 <bob@example.org>::::::::::0:' \
    'sec:u:255:22:EEEEEEEE55555555:1700000000::::::cCD:::FFC1234567::ed25519:' >$sb/keys
printf '%s\n' \
    'pub:u:255:22:FFFFFFFF66666666:1700000000::::::scSC:::::ed25519:' \
    'uid:u::::1700000000::HASH::Carol <carol@example.org>::::::::::0:' >$sb/plain
printf '' >$sb/empty

# One run: status in $gc_rc, stdout lines in $gc_out, stderr in $gc_err,
# the fake gpg's argv in $gc_args, and whether the agent ran in
# $gc_agent_ran. GC_NO_GPG and GC_NO_AGENT drop those tools from PATH.
function gc
    set -l path $sb/bin $sb/tools
    set -q GC_NO_AGENT; or set -a path $sb/agentbin
    set -q GC_NO_GPG; and set path $sb/nogpg
    rm -f $sb/args $sb/agent
    env PATH=(string join : $path) TZ=UTC FAKE_GPG_ARGS=$sb/args \
        FAKE_AGENT_ARGS=$sb/agent \
        FAKE_GPG_FIXTURE=$gc_fixture FAKE_GPG_RC=$gc_gpg_rc \
        (command -s fish) --no-config -c \
        "set -g fish_function_path $repo_root/functions \$fish_function_path; gpg-compact \$argv" \
        -- $argv </dev/null >$sb/out 2>$sb/err
    set -g gc_rc $status
    set -g gc_out (command cat $sb/out)
    set -g gc_err (string collect <$sb/err)
    set -g gc_args
    test -f $sb/args; and set -g gc_args (command cat $sb/args)
    set -g gc_agent_ran (test -f $sb/agent; and echo true; or echo false)
end

# Compare $gc_out to the expected lines, one check per line.
function expect_lines --argument-names label
    set -l want $argv[2..]
    check "$label: line count" (count $want) (count $gc_out)
    for i in (seq (count $want))
        check "$label: line $i" "$want[$i]" "$gc_out[$i]"
    end
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

section "default listing hides dead keys, tags inserted cards"

gc
check "listing exits 0" 0 $gc_rc
check "card keys listed, so the agent is asked" true $gc_agent_ran
expect_lines default \
    'sec>  ed25519/11111111 2023-11-14 [SC] [card:12345678 inserted]' \
    '      Alice : Ops <alice@example.org>' \
    '  ssb>  cv25519/22222222 2023-11-14 [E] [expires: 2027-01-15] [card:12345678 inserted]' \
    '' \
    'sec>  ed25519/55555555 2023-11-14 [C] [disabled] [card:FFC1234567]' \
    ''
check "no hidden-key note when stderr is not a terminal" '' "$gc_err"

section "-a shows everything"

gc -a
expect_lines -a \
    'sec>  ed25519/11111111 2023-11-14 [SC] [card:12345678 inserted]' \
    '      Alice : Ops <alice@example.org>' \
    '      Old \x3a Name <old@example.org> [revoked]' \
    '  ssb>  cv25519/22222222 2023-11-14 [E] [expires: 2027-01-15] [card:12345678 inserted]' \
    '  ssb#  rsa4096/33333333 2020-09-13 [S] [expired: 2022-04-15]' \
    '' \
    'sec   rsa4096/44444444 2020-09-13 [SC] [revoked]' \
    '      Bob\x07 <bob@example.org>' \
    '' \
    'sec>  ed25519/55555555 2023-11-14 [C] [disabled] [card:FFC1234567]' \
    ''

section "-l and -f"

gc -l -f -a
expect_lines "-l -f" \
    'sec>  ed25519/AAAAAAAA11111111 2023-11-14 [SC] [card:12345678 inserted]' \
    '      0000000000000000000000000000AAAAAAAA11111111' \
    '      Alice : Ops <alice@example.org>' \
    '      Old \x3a Name <old@example.org> [revoked]' \
    '  ssb>  cv25519/BBBBBBBB22222222 2023-11-14 [E] [expires: 2027-01-15] [card:12345678 inserted]' \
    '  ssb#  rsa4096/CCCCCCCC33333333 2020-09-13 [S] [expired: 2022-04-15]' \
    '' \
    'sec   rsa4096/DDDDDDDD44444444 2020-09-13 [SC] [revoked]' \
    '      2222222222222222222222222222DDDDDDDD44444444' \
    '      Bob\x07 <bob@example.org>' \
    '' \
    'sec>  ed25519/EEEEEEEE55555555 2023-11-14 [C] [disabled] [card:FFC1234567]' \
    ''

section "card check"

set -gx GC_NO_AGENT 1
gc
check "without the agent, card keys still list" 0 $gc_rc
check "without the agent, the serial is shown unchecked" \
    'sec>  ed25519/11111111 2023-11-14 [SC] [card:12345678]' "$gc_out[1]"
set -e GC_NO_AGENT

set -g gc_fixture $sb/plain
gc
check "no card keys, so the agent is not asked" false $gc_agent_ran
expect_lines plain \
    'pub   ed25519/66666666 2023-11-14 [SC]' \
    '      Carol <carol@example.org>' \
    ''

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
