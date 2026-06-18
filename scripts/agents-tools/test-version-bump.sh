#!/usr/bin/env bash
# Copyright (C) 2026 Rootiest
# SPDX-License-Identifier: AGPL-3.0-or-later
#
# Self-contained tests for version-bump. Run: bash test-version-bump.sh
set -u
HERE="$(cd "$(dirname "$0")" && pwd)"
SCRIPT="$HERE/version-bump"
fail() { echo "FAIL: $1"; exit 1; }

new_repo() {
    local d; d="$(mktemp -d)"
    git -C "$d" init -q
    git -C "$d" config user.email t@t
    git -C "$d" config user.name t
    git -C "$d" config commit.gpgsign false
    printf '%s\n' "$d"
}

# ── precommit: baseline + PATCH + MINOR ──────────────────────────────────────
r="$(new_repo)"; cd "$r"
mkdir -p plans; : > plans/.gitkeep
echo 1.0.0 > .version
git add -A; "$SCRIPT" precommit; git commit -q -m init
[ "$(cat .version)" = 1.0.0 ] || fail "first commit: want 1.0.0 got $(cat .version)"

echo hi > plans/a.md
git add -A; "$SCRIPT" precommit; git commit -q -m content
[ "$(cat .version)" = 1.0.1 ] || fail "content: want 1.0.1 got $(cat .version)"

mkdir -p specs; : > specs/.gitkeep
git add -A; "$SCRIPT" precommit; git commit -q -m structure
[ "$(cat .version)" = 1.1.0 ] || fail "structure: want 1.1.0 got $(cat .version)"

echo x > specs/s.md
git add -A; "$SCRIPT" precommit; git commit -q -m content2
[ "$(cat .version)" = 1.1.1 ] || fail "content2: want 1.1.1 got $(cat .version)"

cd /; rm -rf "$r"
echo "precommit OK"
