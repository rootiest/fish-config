#!/usr/bin/env fish
# Copyright (C) 2026 Rootiest
# SPDX-License-Identifier: AGPL-3.0-or-later
#
# Shared assertion and reporting core for tests/test-*.fish.
#
# One assertion: `check <label> <want> <got>`, string equality. Status
# assertions use the two-line form, which is the point -- it can say "I
# expected exactly 1", where a pass/fail predicate can only say "non-zero":
#
#     __fish_config_op_cascade __probe_cat
#     check "all unset -> enabled" 0 $status
#
# That distinction matters here: __fish_variable_check returns four distinct
# codes (0 truthy, 1 falsy, 2 unset/empty, 3 unrecognized) and the cascade's
# behavior depends on telling 2 and 3 apart from 1.
#
# Boolean assertions use the idiom the vault suite already uses throughout:
#
#     check "label" true (some-test; and echo true; or echo false)

set -g TESTS_RUN 0
set -g TESTS_FAILED 0

# The driver always sets this; the fallback is for running a suite by hand.
if set -q FISH_CONFIG_TEST_ROOT
    set -g repo_root $FISH_CONFIG_TEST_ROOT
else
    set -g repo_root (realpath (dirname (status filename))/..)
end

function section
    echo ""
    echo "== $argv[1] =="
end

function check --argument-names label want got
    set -g TESTS_RUN (math $TESTS_RUN + 1)
    if test "$want" = "$got"
        echo "  PASS  $label"
    else
        echo "  FAIL  $label"
        echo "        want: $want"
        echo "        got:  $got"
        set -g TESTS_FAILED (math $TESTS_FAILED + 1)
    end
end

function report
    echo ""
    echo (math $TESTS_RUN - $TESTS_FAILED)"/$TESTS_RUN passed"
    if set -q FISH_CONFIG_TEST_COUNTS
        echo "$TESTS_RUN $TESTS_FAILED" >>$FISH_CONFIG_TEST_COUNTS
    end
    # Explicit terminal status, never a trailing `if` (AGENTS.md item 5).
    # This is form, not a bug fix: fish clamps `exit`/`return` to 255 rather
    # than wrapping mod 256, so `exit $TESTS_FAILED` could not have produced
    # a false green. Verified: `fish -c 'exit 256'` -> 255, while
    # `sh -c 'exit 256'` -> 0. A boolean is still the right shape -- it
    # composes with `and`/`or`, which a raw count does not.
    test $TESTS_FAILED -eq 0
end
