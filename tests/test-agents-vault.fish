#!/usr/bin/env fish
# Copyright (C) 2026 Rootiest
# SPDX-License-Identifier: AGPL-3.0-or-later
#
# Hermetic tests for the agent memory vault helpers. Every test builds its
# own throwaway git repos and directories under mktemp; nothing touches the
# live vault, ~/.claude, or this checkout.
#
# Usage: fish tests/test-agents-vault.fish

set -l here (realpath (dirname (status filename)))
set -g repo_root (realpath $here/..)
set -p fish_function_path $repo_root/functions

set -g TESTS_RUN 0
set -g TESTS_FAILED 0
set -g TMPDIRS

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

# Create a throwaway git repo, optionally with an origin remote.
function new_repo --argument-names url
    set -l d (mktemp -d)
    set -ga TMPDIRS $d
    git -C $d init -q
    git -C $d config user.email t@t
    git -C $d config user.name t
    git -C $d config commit.gpgsign false
    git -C $d config core.hooksPath /dev/null
    test -n "$url"; and git -C $d remote add origin $url
    printf '%s\n' $d
end

function cleanup
    for d in $TMPDIRS
        test -n "$d"; and rm -rf $d
    end
end

#   ─────────────────────────── slug derivation ───────────────────────────
echo "== _agents_repo_slug =="

set -l want git.rootiest.dev-rootiest-fish-config

set -l r (new_repo https://git.rootiest.dev/rootiest/fish-config.git)
check "https form" $want (_agents_repo_slug $r)

set r (new_repo git@git.rootiest.dev:rootiest/fish-config.git)
check "scp form" $want (_agents_repo_slug $r)

set r (new_repo ssh://git@git.rootiest.dev:22/rootiest/fish-config.git)
check "ssh form with port" $want (_agents_repo_slug $r)

set r (new_repo https://git.rootiest.dev/rootiest/fish-config)
check "no .git suffix" $want (_agents_repo_slug $r)

set r (new_repo HTTPS://Git.Rootiest.DEV/Rootiest/Fish-Config.git)
check "case folded" $want (_agents_repo_slug $r)

# Remote-less: local- prefix, stable across runs, distinct per path.
set -l n1 (new_repo)
set -l s1 (_agents_repo_slug $n1)
set -l s2 (_agents_repo_slug $n1)
check "local slug is stable" $s1 $s2
check "local slug is prefixed" true (string match -q 'local-*' -- $s1; and echo true; or echo false)

set -l n2 (new_repo)
check "local slugs differ by path" false (test "$s1" = (_agents_repo_slug $n2); and echo true; or echo false)

# A non-origin remote is used when origin is absent.
set -l r3 (new_repo)
git -C $r3 remote add upstream https://git.rootiest.dev/rootiest/fish-config.git
check "falls back to first remote" $want (_agents_repo_slug $r3)

cleanup
echo ""
echo (math $TESTS_RUN - $TESTS_FAILED)"/$TESTS_RUN passed"
exit $TESTS_FAILED
