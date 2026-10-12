#!/usr/bin/env fish
# Copyright (C) 2026 Rootiest
# SPDX-License-Identifier: AGPL-3.0-or-later
#
# Run the CI checks locally, in the same container image CI uses.
#
# This checkout doubles as a live ~/.config/fish, so a plain
# `fish tests/run-tests.fish` also sees machine state CI never has: plugins
# Fisher installed into functions/ and conf.d/, gitignored local files, the
# user's git config. This script tests what CI would test instead:
#
#   1. Builds a pristine copy of the working tree: a clone of HEAD plus the
#      uncommitted changes (staged, unstaged and untracked-but-not-ignored).
#      Gitignored files never reach it.
#   2. Streams that copy into a throwaway container from the CI image (no
#      bind mount, so nothing in the container can write to this checkout).
#   3. Runs the CI test job (`fish tests/run-tests.fish`) and the CI docs
#      job's checks (concat, verify-manual.py, pandoc).
#
# Usage: fish tests/run-ci-local.fish [--tests-only] [--pull] [--image IMAGE]
#
# Exit status: 0 when every check passed, 1 when one failed, 2 on a usage
# error or when the environment could not be prepared.

argparse h/help t/tests-only p/pull 'i/image=' -- $argv
or exit 2

if set -q _flag_help
    sed -n '5,25p' (status filename) | string replace -r '^# ?' ''
    exit 0
end

set -l image git.rootiest.dev/rootiest/fish-ci:latest
set -q _flag_image; and set image $_flag_image

set -l runtime
for candidate in docker podman
    if type -q $candidate
        set runtime $candidate
        break
    end
end
if test -z "$runtime"
    echo "run-ci-local: needs docker or podman to run the CI image" >&2
    exit 2
end

set -l repo_root (realpath (dirname (status filename))/..)
set -l head (git -C $repo_root rev-parse HEAD)
or exit 2

#   ──────── Pristine copy of the working tree ────────
set -l work (mktemp -d)
set -l src $work/src
function __ci_local_cleanup --on-event fish_exit --inherit-variable work
    command rm -rf $work
end

git clone -q --no-hardlinks $repo_root $src
and git -C $src checkout -q --detach $head
or begin
    echo "run-ci-local: could not clone $repo_root" >&2
    exit 2
end

# Staged and unstaged changes to tracked files, deletions included.
set -l patch $work/changes.patch
git -C $repo_root diff HEAD --binary >$patch
if test -s $patch
    git -C $src apply --binary $patch
    or begin
        echo "run-ci-local: could not apply the uncommitted changes" >&2
        exit 2
    end
end

# New files git would pick up (not ignored).
set -l untracked (git -C $repo_root ls-files --others --exclude-standard)
for f in $untracked
    mkdir -p $src/(dirname $f)
    command cp -p $repo_root/$f $src/$f
end

set -l dirty clean
if test -s $patch; or set -q untracked[1]
    set dirty "with uncommitted changes"
end
echo "== CI-local: "(git -C $repo_root rev-parse --short HEAD)" ($dirty) in $image =="

#   ──────── Run the CI jobs in the container ────────
# The script runs as `sh` in the container, like a CI `run:` step. tar is
# extracted with --no-same-owner so the tree belongs to the container's
# user, as an actions/checkout tree does (git refuses a repo it doesn't own).
set -l job_script '
set -u
mkdir /work && cd /work && tar -xf - --no-same-owner
failed=0

echo "== CI job: test =="
fish tests/run-tests.fish || failed=1

if [ "$CI_LOCAL_DOCS" = 1 ]; then
    echo
    echo "== CI job: docs =="
    { python3 docs/build-manual.py --concat -o docs/fish-config.md &&
      python3 docs/verify-manual.py &&
      pandoc --standalone --from markdown --to man docs/fish-config.md -o docs/fish-config.1 &&
      echo "docs: OK"; } || { echo "docs: FAILED"; failed=1; }
fi
exit $failed
'

set -l docs 1
set -q _flag_tests_only; and set docs 0
set -l pull_policy missing
set -q _flag_pull; and set pull_policy always

tar -C $src -cf - . | $runtime run --rm -i --pull=$pull_policy \
    -e CI_LOCAL_DOCS=$docs $image sh -c $job_script
set -l rc $pipestatus[2]

echo
if test $rc -eq 0
    echo "== CI-local: PASSED =="
    exit 0
else if test $rc -eq 1
    echo "== CI-local: FAILED ==" >&2
    exit 1
else
    echo "== CI-local: container exited $rc ==" >&2
    exit 2
end
