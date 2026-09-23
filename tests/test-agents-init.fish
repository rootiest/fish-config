#!/usr/bin/env fish
# Copyright (C) 2026 Rootiest
# SPDX-License-Identifier: AGPL-3.0-or-later
#
# Hermetic tests for agents-init's AGENTS.md/CLAUDE.md handling: the
# per-directory sync helper (_agents_init_sync_instructions) and the
# repo-wide discovery loop in agents-init that drives it. Every test
# builds its own throwaway git repo under mktemp; nothing touches this
# checkout.
#
# Runs isolated (no `# MODE:` marker, which means isolated).
#
# Usage: fish tests/test-agents-init.fish

source (realpath (dirname (status filename)))/lib.fish
set -p fish_function_path $repo_root/functions

set -gx GIT_AUTHOR_NAME t
set -gx GIT_AUTHOR_EMAIL t@t
set -gx GIT_COMMITTER_NAME t
set -gx GIT_COMMITTER_EMAIL t@t
set -gx GIT_CONFIG_COUNT 2
set -gx GIT_CONFIG_KEY_0 commit.gpgsign
set -gx GIT_CONFIG_VALUE_0 false
set -gx GIT_CONFIG_KEY_1 init.defaultBranch
set -gx GIT_CONFIG_VALUE_1 main

set -g TMPDIRS

function new_repo
    set -l d (mktemp -d)
    set -ga TMPDIRS $d
    git -C $d init -q
    git -C $d config user.email t@t
    git -C $d config user.name t
    git -C $d config commit.gpgsign false
    git -C $d config core.hooksPath /dev/null
    printf '%s\n' $d
end

function cleanup
    for d in $TMPDIRS
        test -n "$d"; and rm -rf $d
    end
end

echo "== _agents_init_sync_instructions: fresh root =="

set -l r1 (new_repo)
mkdir -p $r1/AGENTS
set -l out1 (_agents_init_sync_instructions $r1 $r1/AGENTS .)
set -l rc1 $status
check "fresh root: exits 0" 0 "$rc1"
check "fresh root: mirror AGENTS.md created" true (test -f $r1/AGENTS/AGENTS.md; and echo true; or echo false)
check "fresh root: no mirror CLAUDE.md" false (test -e $r1/AGENTS/CLAUDE.md; and echo true; or echo false)
check "fresh root: project AGENTS.md links to mirror" AGENTS/AGENTS.md (readlink $r1/AGENTS.md)
check "fresh root: no project CLAUDE.md" false (test -e $r1/CLAUDE.md; and echo true; or echo false)

echo ""
echo "== _agents_init_sync_instructions: idempotent second run =="

set -l out1b (_agents_init_sync_instructions $r1 $r1/AGENTS .)
check "idempotent: second call prints nothing" "" "$out1b"
check "idempotent: still linked" true (test -L $r1/AGENTS.md; and echo true; or echo false)

echo ""
echo "== _agents_init_sync_instructions: root collapse (today's repo shape) =="

set -l r2 (new_repo)
mkdir -p $r2/AGENTS
echo hello >$r2/AGENTS/AGENTS.md
ln -s AGENTS.md $r2/AGENTS/CLAUDE.md
ln -s AGENTS/AGENTS.md $r2/AGENTS.md
ln -s AGENTS/CLAUDE.md $r2/CLAUDE.md
set -l out2 (_agents_init_sync_instructions $r2 $r2/AGENTS .)
set -l rc2 $status
check "root collapse: exits 0" 0 "$rc2"
check "root collapse: mirror CLAUDE.md gone" false (test -e $r2/AGENTS/CLAUDE.md; and echo true; or echo false)
check "root collapse: project CLAUDE.md gone" false (test -e $r2/CLAUDE.md; and echo true; or echo false)
check "root collapse: project AGENTS.md still links correctly" AGENTS/AGENTS.md (readlink $r2/AGENTS.md)
check "root collapse: mirror content preserved" hello (cat $r2/AGENTS/AGENTS.md)

echo ""
echo "== _agents_init_sync_instructions: subdir with only a real CLAUDE.md =="

set -l r3 (new_repo)
mkdir -p $r3/AGENTS $r3/functions
echo scoped >$r3/functions/CLAUDE.md
set -l out3 (_agents_init_sync_instructions $r3 $r3/AGENTS functions)
set -l rc3 $status
check "subdir lone CLAUDE.md: exits 0" 0 "$rc3"
check "subdir lone CLAUDE.md: mirror AGENTS.md created" scoped (cat $r3/AGENTS/functions/AGENTS.md)
check "subdir lone CLAUDE.md: no mirror CLAUDE.md" false (test -e $r3/AGENTS/functions/CLAUDE.md; and echo true; or echo false)
check "subdir lone CLAUDE.md: project AGENTS.md links to mirror" ../AGENTS/functions/AGENTS.md (readlink $r3/functions/AGENTS.md)
check "subdir lone CLAUDE.md: no project CLAUDE.md" false (test -e $r3/functions/CLAUDE.md; and echo true; or echo false)

echo ""
echo "== _agents_init_sync_instructions: inverted mirror (docs/, functions/ today) =="

set -l r4 (new_repo)
mkdir -p $r4/AGENTS/docs $r4/docs
echo docsreal >$r4/AGENTS/docs/CLAUDE.md
ln -s CLAUDE.md $r4/AGENTS/docs/AGENTS.md
ln -s CLAUDE.md $r4/docs/AGENTS.md
ln -s ../AGENTS/docs/CLAUDE.md $r4/docs/CLAUDE.md
set -l out4 (_agents_init_sync_instructions $r4 $r4/AGENTS docs)
set -l rc4 $status
check "inverted mirror: exits 0" 0 "$rc4"
check "inverted mirror: mirror AGENTS.md real" docsreal (cat $r4/AGENTS/docs/AGENTS.md)
check "inverted mirror: mirror CLAUDE.md gone" false (test -e $r4/AGENTS/docs/CLAUDE.md; and echo true; or echo false)
check "inverted mirror: project AGENTS.md relinked directly" ../AGENTS/docs/AGENTS.md (readlink $r4/docs/AGENTS.md)
check "inverted mirror: project CLAUDE.md gone" false (test -e $r4/docs/CLAUDE.md; and echo true; or echo false)

echo ""
echo "== _agents_init_sync_instructions: both real, different content =="

set -l r5 (new_repo)
mkdir -p $r5/AGENTS $r5/conflict
echo agents-version >$r5/conflict/AGENTS.md
echo claude-version >$r5/conflict/CLAUDE.md
set -l err5 (mktemp)
set -ga TMPDIRS $err5
_agents_init_sync_instructions $r5 $r5/AGENTS conflict 2>$err5
set -l rc5 $status
check "conflict: exits 0 (non-fatal skip)" 0 "$rc5"
check "conflict: warns to stderr" true (string match -q '*differ*' -- (cat $err5); and echo true; or echo false)
check "conflict: project AGENTS.md untouched" agents-version (cat $r5/conflict/AGENTS.md)
check "conflict: project CLAUDE.md untouched" claude-version (cat $r5/conflict/CLAUDE.md)
check "conflict: nothing mirrored" false (test -e $r5/AGENTS/conflict/AGENTS.md; and echo true; or echo false)

echo ""
echo "== _agents_init_sync_instructions: both real, identical content =="

set -l r6 (new_repo)
mkdir -p $r6/AGENTS $r6/dup
echo same >$r6/dup/AGENTS.md
echo same >$r6/dup/CLAUDE.md
set -l out6 (_agents_init_sync_instructions $r6 $r6/AGENTS dup)
set -l rc6 $status
check "duplicate: exits 0" 0 "$rc6"
check "duplicate: mirrored" same (cat $r6/AGENTS/dup/AGENTS.md)
check "duplicate: project CLAUDE.md dropped" false (test -e $r6/dup/CLAUDE.md; and echo true; or echo false)
check "duplicate: project AGENTS.md links to mirror" ../AGENTS/dup/AGENTS.md (readlink $r6/dup/AGENTS.md)

echo ""
echo "== _agents_init_sync_instructions: subdir with only a real AGENTS.md =="

set -l r7 (new_repo)
mkdir -p $r7/AGENTS $r7/onlyagents
echo onlyagents >$r7/onlyagents/AGENTS.md
set -l out7 (_agents_init_sync_instructions $r7 $r7/AGENTS onlyagents)
set -l rc7 $status
check "subdir lone AGENTS.md: exits 0" 0 "$rc7"
check "subdir lone AGENTS.md: mirror AGENTS.md created" onlyagents (cat $r7/AGENTS/onlyagents/AGENTS.md)
check "subdir lone AGENTS.md: no mirror CLAUDE.md" false (test -e $r7/AGENTS/onlyagents/CLAUDE.md; and echo true; or echo false)
check "subdir lone AGENTS.md: project AGENTS.md links to mirror" ../AGENTS/onlyagents/AGENTS.md (readlink $r7/onlyagents/AGENTS.md)
check "subdir lone AGENTS.md: no project CLAUDE.md" false (test -e $r7/onlyagents/CLAUDE.md; and echo true; or echo false)

echo ""
echo "== agents-init: end-to-end CLAUDE.md retirement =="

set -l e1 (new_repo)
echo root-real >$e1/CLAUDE.md
mkdir -p $e1/functions
echo scoped-real >$e1/functions/CLAUDE.md
pushd $e1 >/dev/null
set -l ercA (agents-init --agents --silent 2>/dev/null; echo $status)
popd >/dev/null
check "e2e: exits 0" 0 "$ercA"
check "e2e: root CLAUDE.md gone" false (test -e $e1/CLAUDE.md; and echo true; or echo false)
check "e2e: root AGENTS.md links to mirror" AGENTS/AGENTS.md (readlink $e1/AGENTS.md)
check "e2e: root content preserved" root-real (cat $e1/AGENTS.md)
check "e2e: functions CLAUDE.md gone" false (test -e $e1/functions/CLAUDE.md; and echo true; or echo false)
check "e2e: functions AGENTS.md links to mirror" ../AGENTS/functions/AGENTS.md (readlink $e1/functions/AGENTS.md)
check "e2e: functions content preserved" scoped-real (cat $e1/functions/AGENTS.md)
check "e2e: no CLAUDE.md left anywhere under AGENTS/" "" (find $e1/AGENTS -name CLAUDE.md)
check "e2e: gitignore covers AGENTS.md unanchored" true (grep -qx 'AGENTS.md' $e1/.gitignore; and echo true; or echo false)

pushd $e1 >/dev/null
set -l ercB (agents-init --agents --quiet 2>/dev/null)
popd >/dev/null
check "e2e: idempotent second run prints nothing" "" "$ercB"

echo ""
echo "== agents-init: this-repo-shaped inversion is fixed live =="

set -l e2 (new_repo)
mkdir -p $e2/AGENTS/docs $e2/docs
echo docs-content >$e2/AGENTS/docs/CLAUDE.md
ln -s CLAUDE.md $e2/AGENTS/docs/AGENTS.md
ln -s CLAUDE.md $e2/docs/AGENTS.md
ln -s ../AGENTS/docs/CLAUDE.md $e2/docs/CLAUDE.md
pushd $e2 >/dev/null
set -l ercC (agents-init --agents --silent 2>/dev/null; echo $status)
popd >/dev/null
check "inversion fix: exits 0" 0 "$ercC"
check "inversion fix: mirror AGENTS.md real" docs-content (cat $e2/AGENTS/docs/AGENTS.md)
check "inversion fix: mirror CLAUDE.md gone" false (test -e $e2/AGENTS/docs/CLAUDE.md; and echo true; or echo false)
check "inversion fix: project docs/AGENTS.md relinked directly" ../AGENTS/docs/AGENTS.md (readlink $e2/docs/AGENTS.md)
check "inversion fix: project docs/CLAUDE.md gone" false (test -e $e2/docs/CLAUDE.md; and echo true; or echo false)

echo ""
echo "== agents-init: stale anchored gitignore lines migrated =="

set -l e3 (new_repo)
mkdir -p $e3/AGENTS
echo real-agents >$e3/AGENTS/AGENTS.md
ln -s AGENTS/AGENTS.md $e3/AGENTS.md
printf '%s\n' AGENTS/ "/AGENTS.md" "/CLAUDE.md" >$e3/.gitignore
pushd $e3 >/dev/null
set -l ercD (agents-init --agents --silent 2>/dev/null; echo $status)
popd >/dev/null
check "stale gitignore: exits 0" 0 "$ercD"
check "stale gitignore: anchored /AGENTS.md line removed" false (grep -qxF '/AGENTS.md' $e3/.gitignore; and echo true; or echo false)
check "stale gitignore: anchored /CLAUDE.md line removed" false (grep -qxF '/CLAUDE.md' $e3/.gitignore; and echo true; or echo false)
check "stale gitignore: unanchored AGENTS.md pattern present" true (grep -qxF 'AGENTS.md' $e3/.gitignore; and echo true; or echo false)

cleanup
report
