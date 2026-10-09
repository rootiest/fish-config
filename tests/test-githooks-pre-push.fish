#!/usr/bin/env fish
# Copyright (C) 2026 Rootiest
# SPDX-License-Identifier: AGPL-3.0-or-later
#
# Coverage for .githooks/pre-push: the chained global pre-push hook must
# receive the exact ref lines git passed to the local hook (issue #206). The
# signature loop used to consume stdin, so the chained hook saw an empty one.
#
# Runs isolated (no `# MODE:` marker). Fully hermetic: the real hook runs in a
# throwaway repo, HOME is a temp dir, GIT_CONFIG_GLOBAL points at a temp file
# that sets core.hooksPath to a stub hook dir, and the system config is off.
# Only non-branch refs and branch deletions are fed to the hook for the
# pass-through cases, which skip signature verification, so no gpg/YubiKey
# prompt and no network can occur. The rejection case uses an unsigned commit
# made with commit.gpgsign=false.

source (realpath (dirname (status filename)))/lib.fish

set -l hook $repo_root/.githooks/pre-push
set -l tmp (mktemp -d)
set -l zero 0000000000000000000000000000000000000000

mkdir -p $tmp/home $tmp/ghooks $tmp/repo
printf '[core]\n\thooksPath = %s\n' $tmp/ghooks >$tmp/gitconfig

# Stub global hook: record its arguments and stdin verbatim.
printf '%s\n' '#!/bin/sh' \
    'printf "%s\n" "$@" >"$STUB_OUT.args"' \
    'cat >"$STUB_OUT.stdin"' >$tmp/ghooks/pre-push
chmod +x $tmp/ghooks/pre-push

set -l hermetic HOME=$tmp/home GIT_CONFIG_GLOBAL=$tmp/gitconfig \
    GIT_CONFIG_SYSTEM=/dev/null GIT_CONFIG_NOSYSTEM=1 STUB_OUT=$tmp/out \
    GIT_AUTHOR_NAME=t GIT_AUTHOR_EMAIL=t@example.invalid \
    GIT_COMMITTER_NAME=t GIT_COMMITTER_EMAIL=t@example.invalid

cd $tmp/repo
env $hermetic git init -q .
env $hermetic git -c commit.gpgsign=false commit -q --allow-empty -m init
set -l sha (env $hermetic git rev-parse HEAD)

section "pre-push: chained hook receives the ref lines"
set -l lines "refs/tags/v1 $sha refs/tags/v1 $zero" "(delete) $zero refs/heads/gone $sha"
printf '%s\n' $lines | env $hermetic bash $hook origin url
check "hook exits 0" 0 $status
check "stub received the exact ref lines" (string join \n -- $lines | string collect) (string collect <$tmp/out.stdin)
check "stub received the hook arguments" "origin url" (string join " " (string split \n -- (string trim (cat $tmp/out.args))))

section "pre-push: empty push stays empty"
rm -f $tmp/out.stdin
env $hermetic bash $hook origin url </dev/null
check "hook exits 0" 0 $status
check "stub stdin is empty" 0 (stat -c %s $tmp/out.stdin)

section "pre-push: unsigned branch commit is still rejected"
rm -f $tmp/out.stdin
printf 'refs/heads/main %s refs/heads/main %s\n' $sha $zero | env $hermetic bash $hook origin url 2>/dev/null
check "hook exits 1" 1 $status
check "chained hook not run on rejection" false (test -e $tmp/out.stdin; and echo true; or echo false)

cd $repo_root
rm -rf $tmp
report
