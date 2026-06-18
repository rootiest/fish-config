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

# ── prepmsg: subject suffix + idempotency ────────────────────────────────────
r="$(new_repo)"; cd "$r"
echo 1.2.3 > .version
msg="$(mktemp)"
printf 'chore: do thing\n' > "$msg"
"$SCRIPT" prepmsg "$msg"
head -n1 "$msg" | grep -qF 'chore: do thing (v1.2.3)' || fail "prepmsg: subject not suffixed"
"$SCRIPT" prepmsg "$msg"
[ "$(grep -c '(v1.2.3)' "$msg")" -eq 1 ] || fail "prepmsg: not idempotent"

# body preserved
printf 'subject\n\nbody line\n' > "$msg"
echo 2.0.0 > .version
"$SCRIPT" prepmsg "$msg"
head -n1 "$msg" | grep -qF 'subject (v2.0.0)' || fail "prepmsg: body-case subject"
grep -qF 'body line' "$msg" || fail "prepmsg: body lost"

rm -f "$msg"; cd /; rm -rf "$r"
echo "prepmsg OK"

# ── end-to-end via real hooks + core.hooksPath ───────────────────────────────
r="$(new_repo)"; cd "$r"
mkdir -p .agents-tools/hooks
cp "$HERE/version-bump" .agents-tools/version-bump
cp "$HERE/hooks/pre-commit" .agents-tools/hooks/pre-commit
cp "$HERE/hooks/prepare-commit-msg" .agents-tools/hooks/prepare-commit-msg
chmod +x .agents-tools/version-bump .agents-tools/hooks/pre-commit .agents-tools/hooks/prepare-commit-msg
git config core.hooksPath .agents-tools/hooks
echo 1.0.0 > .version
mkdir -p plans; : > plans/.gitkeep
git add -A; git commit -q -m "init"
[ "$(cat .version)" = 1.0.0 ] || fail "e2e baseline: want 1.0.0 got $(cat .version)"
git log -1 --pretty=%s | grep -qF 'init (v1.0.0)' || fail "e2e baseline message: $(git log -1 --pretty=%s)"

mkdir -p specs; : > specs/.gitkeep
git add -A; git commit -q -m "add specs"
[ "$(cat .version)" = 1.1.0 ] || fail "e2e structure: want 1.1.0 got $(cat .version)"
git log -1 --pretty=%s | grep -qF 'add specs (v1.1.0)' || fail "e2e structure message: $(git log -1 --pretty=%s)"

echo z > specs/z.md
git add -A; git commit -q -m "edit spec"
[ "$(cat .version)" = 1.1.1 ] || fail "e2e content: want 1.1.1 got $(cat .version)"

cd /; rm -rf "$r"
echo "e2e OK"
