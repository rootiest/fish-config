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
check "fresh root: mirror AGENTS.md is exactly the shared stub" (_agents_init_stub | string collect) (string collect <$r1/AGENTS/AGENTS.md)

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
set -l ercA (agents-init --private --agents --silent 2>/dev/null; echo $status)
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

echo ""
echo "== agents-init: discovery stays out of nested repos and dot-dirs =="

set -l e4 (new_repo)
mkdir -p $e4/sub $e4/.claude $e4/vendor/other/AGENTS
git -C $e4/sub init -q
mkdir -p $e4/.gemini
echo nested-claude >$e4/sub/CLAUDE.md
echo tool-claude >$e4/.claude/CLAUDE.md
echo tool-agents >$e4/.gemini/AGENTS.md
echo foreign-mirror >$e4/vendor/other/AGENTS/CLAUDE.md
echo own-docs >$e4/vendor/CLAUDE.md
pushd $e4 >/dev/null
set -l ercE (agents-init --private --agents --silent 2>/dev/null; echo $status)
popd >/dev/null
check "containment: exits 0" 0 "$ercE"
check "containment: nested repo got no AGENTS.md" false (test -e $e4/sub/AGENTS.md -o -L $e4/sub/AGENTS.md; and echo true; or echo false)
check "containment: nested repo CLAUDE.md still real" nested-claude (test -L $e4/sub/CLAUDE.md; or cat $e4/sub/CLAUDE.md)
check "containment: no mirror for nested repo" false (test -e $e4/AGENTS/sub; and echo true; or echo false)
check "containment: .claude/CLAUDE.md untouched" tool-claude (test -L $e4/.claude/CLAUDE.md; or cat $e4/.claude/CLAUDE.md)
check "containment: .gemini/AGENTS.md untouched" tool-agents (test -L $e4/.gemini/AGENTS.md; or cat $e4/.gemini/AGENTS.md)
check "containment: no mirror for .claude" false (test -e $e4/AGENTS/.claude; and echo true; or echo false)
check "containment: foreign AGENTS/ dir untouched" foreign-mirror (test -L $e4/vendor/other/AGENTS/CLAUDE.md; or cat $e4/vendor/other/AGENTS/CLAUDE.md)
check "containment: ordinary subdir still discovered" own-docs (cat $e4/AGENTS/vendor/AGENTS.md)
check "containment: ordinary subdir linked" ../AGENTS/vendor/AGENTS.md (readlink $e4/vendor/AGENTS.md)

echo ""
echo "== agents-init: non-git root syncs only itself =="

set -l n1 (mktemp -d)
set -ga TMPDIRS $n1
mkdir -p $n1/sub
echo root-agents >$n1/AGENTS.md
echo sub-agents >$n1/sub/AGENTS.md
mkdir -p $n1/sub2
echo sub-claude >$n1/sub2/CLAUDE.md
pushd $n1 >/dev/null
set -l ercF (set -lx GIT_CEILING_DIRECTORIES (path dirname $n1); agents-init --agents --silent 2>/dev/null; echo $status)
popd >/dev/null
check "non-git: exits 0" 0 "$ercF"
check "non-git: root adopted into mirror" root-agents (cat $n1/AGENTS/AGENTS.md)
check "non-git: root linked" AGENTS/AGENTS.md (readlink $n1/AGENTS.md)
check "non-git: subdir AGENTS.md untouched" sub-agents (test -L $n1/sub/AGENTS.md; or cat $n1/sub/AGENTS.md)
check "non-git: subdir CLAUDE.md untouched" sub-claude (test -L $n1/sub2/CLAUDE.md; or cat $n1/sub2/CLAUDE.md)
check "non-git: no mirror for subdirs" false (test -e $n1/AGENTS/sub -o -e $n1/AGENTS/sub2; and echo true; or echo false)

echo ""
echo "== _agents_init_sync_instructions: real file written after mirror settled =="

set -l s1 (new_repo)
mkdir -p $s1/AGENTS
echo settled >$s1/AGENTS/AGENTS.md
echo settled >$s1/AGENTS.md
echo settled >$s1/CLAUDE.md
set -l outS1 (_agents_init_sync_instructions $s1 $s1/AGENTS . 2>/dev/null)
set -l rcS1 $status
check "settled identical: exits 0" 0 "$rcS1"
check "settled identical: AGENTS.md replaced by link" AGENTS/AGENTS.md (readlink $s1/AGENTS.md)
check "settled identical: duplicate CLAUDE.md dropped" false (test -e $s1/CLAUDE.md; and echo true; or echo false)
check "settled identical: mirror intact" settled (cat $s1/AGENTS/AGENTS.md)

set -l s2 (new_repo)
mkdir -p $s2/AGENTS
echo settled >$s2/AGENTS/AGENTS.md
echo rewritten >$s2/AGENTS.md
set -l errS2 (_agents_init_sync_instructions $s2 $s2/AGENTS . 2>&1 >/dev/null)
set -l rcS2 $status
check "settled differs (AGENTS.md): exits 0" 0 "$rcS2"
check "settled differs (AGENTS.md): real file kept" rewritten (test -L $s2/AGENTS.md; or cat $s2/AGENTS.md)
check "settled differs (AGENTS.md): warned on stderr" true (string match -q '*differ*' -- "$errS2"; and echo true; or echo false)
check "settled differs (AGENTS.md): mirror intact" settled (cat $s2/AGENTS/AGENTS.md)

set -l s3 (new_repo)
mkdir -p $s3/AGENTS
echo settled >$s3/AGENTS/AGENTS.md
ln -s AGENTS/AGENTS.md $s3/AGENTS.md
echo recreated >$s3/CLAUDE.md
set -l errS3 (_agents_init_sync_instructions $s3 $s3/AGENTS . 2>&1 >/dev/null)
set -l rcS3 $status
check "settled differs (CLAUDE.md): exits 0" 0 "$rcS3"
check "settled differs (CLAUDE.md): real file kept" recreated (cat $s3/CLAUDE.md)
check "settled differs (CLAUDE.md): warned on stderr" true (string match -q '*differ*' -- "$errS3"; and echo true; or echo false)
check "settled differs (CLAUDE.md): link intact" AGENTS/AGENTS.md (readlink $s3/AGENTS.md)

echo ""
echo "== _agents_init_sync_instructions: deliberately git-tracked files are protected =="

# Tracked (committed) + populated .gitignore: left alone.
set -l p1 (new_repo)
mkdir -p $p1/AGENTS
echo node_modules/ >$p1/.gitignore
echo team-rules >$p1/AGENTS.md
git -C $p1 add .gitignore AGENTS.md
git -C $p1 commit -qm init
set -l errP1 (_agents_init_sync_instructions $p1 $p1/AGENTS . 2>&1 >/dev/null)
set -l rcP1 $status
check "tracked+ignore: exits 0" 0 "$rcP1"
check "tracked+ignore: still a real file" team-rules (test -L $p1/AGENTS.md; or cat $p1/AGENTS.md)
check "tracked+ignore: mirror not populated" false (test -e $p1/AGENTS/AGENTS.md; and echo true; or echo false)
check "tracked+ignore: still tracked, unmodified" "" (git -C $p1 status --porcelain -- AGENTS.md)
check "tracked+ignore: warned on stderr, naming the file" true (string match -q '*AGENTS.md tracked by git*' -- "$errP1"; and echo true; or echo false)

# Untracked because gitignored + populated .gitignore: adopted normally.
set -l p2 (new_repo)
mkdir -p $p2/AGENTS
echo 'AGENTS.md' >$p2/.gitignore
git -C $p2 add .gitignore
git -C $p2 commit -qm init
echo ignored-local >$p2/AGENTS.md
set -l outP2 (_agents_init_sync_instructions $p2 $p2/AGENTS . 2>/dev/null)
check "gitignored untracked: adopted into mirror" ignored-local (cat $p2/AGENTS/AGENTS.md)
check "gitignored untracked: linked" AGENTS/AGENTS.md (readlink $p2/AGENTS.md)

# Tracked but no .gitignore at all (bootstrap): adopted anyway.
set -l p3 (new_repo)
mkdir -p $p3/AGENTS
echo bootstrap >$p3/AGENTS.md
git -C $p3 add AGENTS.md
git -C $p3 commit -qm init
set -l outP3 (_agents_init_sync_instructions $p3 $p3/AGENTS . 2>/dev/null)
check "tracked, no .gitignore: adopted into mirror" bootstrap (cat $p3/AGENTS/AGENTS.md)
check "tracked, no .gitignore: linked" AGENTS/AGENTS.md (readlink $p3/AGENTS.md)

# Tracked but .gitignore empty: same bootstrap rule.
set -l p3b (new_repo)
mkdir -p $p3b/AGENTS
touch $p3b/.gitignore
echo bootstrap-empty >$p3b/AGENTS.md
git -C $p3b add .gitignore AGENTS.md
git -C $p3b commit -qm init
set -l outP3b (_agents_init_sync_instructions $p3b $p3b/AGENTS . 2>/dev/null)
check "tracked, empty .gitignore: adopted into mirror" bootstrap-empty (cat $p3b/AGENTS/AGENTS.md)
check "tracked, empty .gitignore: linked" AGENTS/AGENTS.md (readlink $p3b/AGENTS.md)

# Staged, never committed + populated .gitignore: staged is enough.
set -l p4 (new_repo)
mkdir -p $p4/AGENTS
echo node_modules/ >$p4/.gitignore
echo staged-only >$p4/AGENTS.md
git -C $p4 add AGENTS.md
set -l errP4 (_agents_init_sync_instructions $p4 $p4/AGENTS . 2>&1 >/dev/null)
check "staged-only: still a real file" staged-only (test -L $p4/AGENTS.md; or cat $p4/AGENTS.md)
check "staged-only: mirror not populated" false (test -e $p4/AGENTS/AGENTS.md; and echo true; or echo false)
check "staged-only: warned on stderr" true (string match -q '*tracked by git*' -- "$errP4"; and echo true; or echo false)

# Never added, not matched by .gitignore, populated .gitignore: adopted.
set -l p5 (new_repo)
mkdir -p $p5/AGENTS
echo node_modules/ >$p5/.gitignore
git -C $p5 add .gitignore
git -C $p5 commit -qm init
echo brand-new >$p5/CLAUDE.md
set -l outP5 (_agents_init_sync_instructions $p5 $p5/AGENTS . 2>/dev/null)
check "never added: adopted into mirror" brand-new (cat $p5/AGENTS/AGENTS.md)
check "never added: linked" AGENTS/AGENTS.md (readlink $p5/AGENTS.md)
check "never added: CLAUDE.md gone" false (test -e $p5/CLAUDE.md; and echo true; or echo false)

# A pair where only CLAUDE.md is tracked: both left, only CLAUDE.md named.
set -l p5b (new_repo)
mkdir -p $p5b/AGENTS
echo node_modules/ >$p5b/.gitignore
echo pair >$p5b/CLAUDE.md
git -C $p5b add .gitignore CLAUDE.md
git -C $p5b commit -qm init
echo pair >$p5b/AGENTS.md
set -l errP5b (_agents_init_sync_instructions $p5b $p5b/AGENTS . 2>&1 >/dev/null)
check "pair, one tracked: AGENTS.md left real" pair (test -L $p5b/AGENTS.md; or cat $p5b/AGENTS.md)
check "pair, one tracked: CLAUDE.md left real" pair (test -L $p5b/CLAUDE.md; or cat $p5b/CLAUDE.md)
check "pair, one tracked: mirror not populated" false (test -e $p5b/AGENTS/AGENTS.md; and echo true; or echo false)
check "pair, one tracked: names only the tracked file" true (string match -q '*: CLAUDE.md tracked by git*' -- "$errP5b"; and echo true; or echo false)

# Settled mirror (step 4): a tracked real file arriving later is protected,
# whether it differs from the mirror or is byte-identical to it.
set -l p7 (new_repo)
mkdir -p $p7/AGENTS
echo settled >$p7/AGENTS/AGENTS.md
ln -s AGENTS/AGENTS.md $p7/AGENTS.md
echo node_modules/ >$p7/.gitignore
echo team-claude >$p7/CLAUDE.md
git -C $p7 add .gitignore CLAUDE.md
git -C $p7 commit -qm init
set -l errP7 (_agents_init_sync_instructions $p7 $p7/AGENTS . 2>&1 >/dev/null)
check "settled, tracked differs: exits 0" 0 "$status"
check "settled, tracked differs: CLAUDE.md kept" team-claude (test -L $p7/CLAUDE.md; or cat $p7/CLAUDE.md)
check "settled, tracked differs: protection wins over diff warning" true (string match -q '*CLAUDE.md tracked by git*' -- "$errP7"; and echo true; or echo false)
check "settled, tracked differs: mirror intact" settled (cat $p7/AGENTS/AGENTS.md)

set -l p7b (new_repo)
mkdir -p $p7b/AGENTS
echo settled >$p7b/AGENTS/AGENTS.md
echo node_modules/ >$p7b/.gitignore
echo settled >$p7b/AGENTS.md
git -C $p7b add .gitignore AGENTS.md
git -C $p7b commit -qm init
set -l errP7b (_agents_init_sync_instructions $p7b $p7b/AGENTS . 2>&1 >/dev/null)
check "settled, tracked identical: still a real file" true (test -f $p7b/AGENTS.md; and not test -L $p7b/AGENTS.md; and echo true; or echo false)
check "settled, tracked identical: warned on stderr" true (string match -q '*AGENTS.md tracked by git*' -- "$errP7b"; and echo true; or echo false)

echo ""
echo "== agents-init: tracked subdir file protected, generated dirs pruned =="

set -l e5 (new_repo)
echo node_modules/ >$e5/.gitignore
mkdir -p $e5/team $e5/build $e5/dist $e5/out $e5/target
echo team-shared >$e5/team/CLAUDE.md
for g in build dist out target
    echo gen-$g >$e5/$g/AGENTS.md
end
git -C $e5 add .gitignore team/CLAUDE.md build/AGENTS.md
git -C $e5 commit -qm init
pushd $e5 >/dev/null
set -l ercG (agents-init --private --agents --silent 2>/dev/null; echo $status)
popd >/dev/null
check "subdir protection: exits 0" 0 "$ercG"
check "subdir protection: team/CLAUDE.md still real" team-shared (test -L $e5/team/CLAUDE.md; or cat $e5/team/CLAUDE.md)
check "subdir protection: no team/AGENTS.md created" false (test -e $e5/team/AGENTS.md -o -L $e5/team/AGENTS.md; and echo true; or echo false)
check "subdir protection: no mirror file for team" false (test -e $e5/AGENTS/team/AGENTS.md; and echo true; or echo false)
check "subdir protection: team/CLAUDE.md unmodified in git" "" (git -C $e5 status --porcelain -- team/CLAUDE.md)
check "subdir protection: root still scaffolded" AGENTS/AGENTS.md (readlink $e5/AGENTS.md)
for g in build dist out target
    check "pruned $g/: AGENTS.md untouched" gen-$g (test -L $e5/$g/AGENTS.md; or cat $e5/$g/AGENTS.md)
    check "pruned $g/: no mirror" false (test -e $e5/AGENTS/$g; and echo true; or echo false)
end

echo ""
echo "== _agents_init_path_is_protected: glob characters in filenames not false-matched =="

# Glob character filenames (e.g. a[1]) should be treated literally, not as glob patterns.
# A committed file a1/AGENTS.md should NOT falsely protect an untracked a[1]/AGENTS.md
# when checking if a[1]/AGENTS.md is protected.
set -l g1 (new_repo)
mkdir -p $g1/a1
echo committed-a1 >$g1/a1/AGENTS.md
git -C $g1 add a1/AGENTS.md
git -C $g1 commit -qm init
mkdir -p "$g1/a[1]"
echo untracked-bracket >"$g1/a[1]/AGENTS.md"
echo node_modules/ >$g1/.gitignore
git -C $g1 add .gitignore
git -C $g1 commit -qm add-ignore
# Before the fix, this would return 0 (protected) due to glob matching a1/AGENTS.md
# After the fix, it should return 1 (not protected) since a[1]/AGENTS.md is untracked
_agents_init_path_is_protected $g1 "$g1/a[1]/AGENTS.md"
set -l protected $status
check "glob false-match: untracked a[1]/AGENTS.md is not protected" 1 "$protected"

echo ""
echo "== _agents_init_find: shared prune set =="

set -l pf (new_repo)
mkdir -p $pf/src $pf/node_modules/pkg $pf/.claude $pf/AGENTS $pf/build $pf/dist $pf/out $pf/target $pf/nested
git -C $pf/nested init -q
ln -s ../x $pf/src/link
ln -s x $pf/node_modules/pkg/link
ln -s x $pf/.claude/link
ln -s x $pf/AGENTS/link
ln -s x $pf/build/link
ln -s x $pf/dist/link
ln -s x $pf/out/link
ln -s x $pf/target/link
ln -s x $pf/nested/link
check "find: only the unpruned symlink" $pf/src/link (_agents_init_find $pf -type l -print | string join ,)
check "find: no root -> status 1" 1 (_agents_init_find ""; echo $status)

echo ""
echo "== agents-init: opt-out marker =="

set -l m1 (new_repo)
git -C $m1 config agents-init.disabled true
pushd $m1 >/dev/null
set -l mrc1 (agents-init --silent 2>/dev/null; echo $status)
popd >/dev/null
check "git key: exits 0" 0 "$mrc1"
check "git key: nothing scaffolded" false (test -e $m1/AGENTS -o -L $m1/AGENTS.md; and echo true; or echo false)

set -l m2 (new_repo)
touch $m2/.agents-disabled
pushd $m2 >/dev/null
set -l mrc2 (agents-init --silent 2>/dev/null; echo $status)
popd >/dev/null
check "marker file: exits 0" 0 "$mrc2"
check "marker file: nothing scaffolded" false (test -e $m2/AGENTS -o -L $m2/AGENTS.md; and echo true; or echo false)

set -l m3 (new_repo)
git -C $m3 config agents-init.disabled true
pushd $m3 >/dev/null
set -l mrc3 (agents-init --private --enable --silent 2>/dev/null; echo $status)
popd >/dev/null
check "--enable: exits 0" 0 "$mrc3"
check "--enable: git key unset" 1 (git -C $m3 config --get agents-init.disabled >/dev/null; echo $status)
check "--enable: scaffold created" AGENTS/AGENTS.md (readlink $m3/AGENTS.md)

set -l m4 (new_repo)
touch $m4/.agents-disabled
pushd $m4 >/dev/null
set -l mrc4 (agents-init --enable --silent 2>/dev/null; echo $status)
popd >/dev/null
check "--enable with marker file: exits 1" 1 "$mrc4"
check "--enable with marker file: nothing scaffolded" false (test -e $m4/AGENTS -o -L $m4/AGENTS.md; and echo true; or echo false)
check "--enable with marker file: file kept" true (test -e $m4/.agents-disabled; and echo true; or echo false)

set -l m5 (new_repo)
git -C $m5 config agents-init.disabled true
pushd $m5 >/dev/null
set -l mout5 (agents-init 2>/dev/null)
popd >/dev/null
check "git key, verbose: note names the marker" true (string match -q -- '*agents-init.disabled*' "$mout5"; and echo true; or echo false)

# --enable only clears the local key. A key at another scope (here a
# throwaway GIT_CONFIG_GLOBAL file, never the real ~/.gitconfig) keeps the
# project disabled: it must say where, exit non-zero and not scaffold.
set -l m6 (new_repo)
set -l gcfg6 (mktemp)
set -ga TMPDIRS $gcfg6
git config --file $gcfg6 agents-init.disabled true
git -C $m6 config agents-init.disabled true
set -gx GIT_CONFIG_GLOBAL $gcfg6
pushd $m6 >/dev/null
set -l merr6 (mktemp)
set -ga TMPDIRS $merr6
agents-init --private --enable --silent 2>$merr6
set -l mrc6 $status
popd >/dev/null
set -e GIT_CONFIG_GLOBAL
check "--enable, global key: exits 1" 1 "$mrc6"
check "--enable, global key: warning names the origin file" true (string match -q -- "*$gcfg6*" (string collect <$merr6); and echo true; or echo false)
check "--enable, global key: local key still unset" 1 (git -C $m6 config --local --get agents-init.disabled >/dev/null; echo $status)
check "--enable, global key: nothing scaffolded" false (test -e $m6/AGENTS -o -L $m6/AGENTS.md; and echo true; or echo false)

# Only a global key (no local one): same outcome, nothing to unset.
set -l m7 (new_repo)
set -gx GIT_CONFIG_GLOBAL $gcfg6
pushd $m7 >/dev/null
agents-init --private --enable --silent 2>/dev/null
set -l mrc7 $status
popd >/dev/null
set -e GIT_CONFIG_GLOBAL
check "--enable, global key only: exits 1" 1 "$mrc7"
check "--enable, global key only: nothing scaffolded" false (test -e $m7/AGENTS -o -L $m7/AGENTS.md; and echo true; or echo false)

# --enable on a project that was never disabled still works and is silent.
set -l m8 (new_repo)
pushd $m8 >/dev/null
agents-init --private --enable --silent 2>/dev/null
set -l mrc8 $status
popd >/dev/null
check "--enable, nothing disabled: exits 0" 0 "$mrc8"
check "--enable, nothing disabled: scaffold created" AGENTS/AGENTS.md (readlink $m8/AGENTS.md)

#   ───────────────────────────── public mode ─────────────────────────────
function _is_link --argument-names p want
    test -L $p; and test (readlink $p) = $want; and echo true; or echo false
end
function _ignored --argument-names root path
    git -C $root check-ignore -q --no-index -- $path; and echo true; or echo false
end

echo ""
echo "== agents-init: public mode is the default for a new project =="

set -l p1 (new_repo)
pushd $p1 >/dev/null
set -l prc1 (agents-init --silent 2>/dev/null; echo $status)
set -l pout1b (agents-init --quiet 2>&1)
popd >/dev/null
check "public: exits 0" 0 "$prc1"
check "public: AGENTS/.mode is public" public (cat $p1/AGENTS/.mode)
check "public: root AGENTS.md is a real file" true (test -f $p1/AGENTS.md -a ! -L $p1/AGENTS.md; and echo true; or echo false)
check "public: root AGENTS.md is the public starter" (_agents_init_stub --public | string collect) (string collect <$p1/AGENTS.md)
check "public: starter imports @AGENTS.local.md outside backticks" true (grep -qE '(^|[^`])@AGENTS\.local\.md' $p1/AGENTS.md; and echo true; or echo false)
check "public: private file is real in AGENTS/" true (test -f $p1/AGENTS/AGENTS.local.md -a ! -L $p1/AGENTS/AGENTS.local.md; and echo true; or echo false)
check "public: private file is the local stub" (_agents_init_stub --local | string collect) (string collect <$p1/AGENTS/AGENTS.local.md)
check "public: AGENTS.local.md links into AGENTS/" true (_is_link $p1/AGENTS.local.md AGENTS/AGENTS.local.md)
check "public: AGENTS/AGENTS.md links back to the public file" true (_is_link $p1/AGENTS/AGENTS.md ../AGENTS.md)
check "public: AGENTS.md is NOT ignored" false (_ignored $p1 AGENTS.md)
check "public: AGENTS.local.md is ignored" true (_ignored $p1 AGENTS.local.md)
check "public: AGENTS/ is ignored" true (_ignored $p1 AGENTS/x)
check "public: the private file is committed in AGENTS/" true (git -C $p1/AGENTS ls-files --error-unmatch AGENTS.local.md >/dev/null 2>&1; and echo true; or echo false)
check "public: nothing committed in the project" 1 (git -C $p1 rev-parse -q --verify HEAD >/dev/null; echo $status)
check "public: idempotent second run prints nothing" "" "$pout1b"

echo ""
echo "== agents-init: public mode never moves a real AGENTS.md =="

# Tracked, in a repo with NO .gitignore: the old protection rule needs a
# non-empty .gitignore, so private mode would adopt this file.
set -l p2 (new_repo)
echo team-public >$p2/AGENTS.md
mkdir -p $p2/lib
echo lib-public >$p2/lib/AGENTS.md
git -C $p2 add AGENTS.md lib/AGENTS.md
git -C $p2 commit -qm init
pushd $p2 >/dev/null
agents-init --silent 2>/dev/null
popd >/dev/null
check "keep: tracked root AGENTS.md untouched" team-public (test -L $p2/AGENTS.md; or cat $p2/AGENTS.md)
check "keep: tracked child AGENTS.md untouched" lib-public (test -L $p2/lib/AGENTS.md; or cat $p2/lib/AGENTS.md)
check "keep: no change in git status" "" (git -C $p2 status --porcelain -- AGENTS.md lib/AGENTS.md)
check "keep: child mirror links back" true (_is_link $p2/AGENTS/lib/AGENTS.md ../../lib/AGENTS.md)
check "keep: no child local file invented" false (test -e $p2/AGENTS/lib/AGENTS.local.md -o -L $p2/lib/AGENTS.local.md; and echo true; or echo false)

set -l p3 (new_repo)
echo untracked-public >$p3/AGENTS.md
pushd $p3 >/dev/null
agents-init --silent 2>/dev/null
popd >/dev/null
check "keep: untracked real AGENTS.md untouched" untracked-public (test -L $p3/AGENTS.md; or cat $p3/AGENTS.md)

echo ""
echo "== agents-init: public mode links, adopts and hints =="

set -l p4 (new_repo)
mkdir -p $p4/docs
echo docs-public >$p4/docs/AGENTS.md
pushd $p4 >/dev/null
agents-init --silent 2>/dev/null
echo docs-private >$p4/AGENTS/docs/AGENTS.local.md
agents-init --silent 2>/dev/null
popd >/dev/null
check "child: user-created private file is linked in" true (_is_link $p4/docs/AGENTS.local.md ../AGENTS/docs/AGENTS.local.md)
check "child: private content reachable through the link" docs-private (cat $p4/docs/AGENTS.local.md)
check "child: child AGENTS.local.md ignored" true (_ignored $p4 docs/AGENTS.local.md)

pushd $p4 >/dev/null
set -l hint (agents-init 2>&1 | string replace -ra '\e\[[0-9;]*m' '')
popd >/dev/null
check "hint: missing @AGENTS.local.md reference is reported" true (string match -q '*docs/AGENTS.md does not reference @AGENTS.local.md*' -- $hint; and echo true; or echo false)
pushd $p4 >/dev/null
set -l quiet_hint (agents-init --quiet 2>&1)
popd >/dev/null
check "hint: not printed by a quiet (wrapper) run" "" "$quiet_hint"

set -l p5 (new_repo)
pushd $p5 >/dev/null
agents-init --silent 2>/dev/null
rm $p5/AGENTS.local.md
echo agent-wrote-this >$p5/AGENTS.local.md
agents-init --silent 2>/dev/null
popd >/dev/null
check "adopt: a real base AGENTS.local.md differing from the mirror is left alone" agent-wrote-this (test -L $p5/AGENTS.local.md; or cat $p5/AGENTS.local.md)

set -l p6 (new_repo)
mkdir -p $p6/sub
echo sub-public >$p6/sub/AGENTS.md
echo sub-written >$p6/sub/AGENTS.local.md
echo stray-claude >$p6/CLAUDE.md
pushd $p6 >/dev/null
agents-init --silent 2>/dev/null
popd >/dev/null
check "adopt: real child AGENTS.local.md moved into AGENTS/" sub-written (cat $p6/AGENTS/sub/AGENTS.local.md)
check "adopt: and linked back" true (_is_link $p6/sub/AGENTS.local.md ../AGENTS/sub/AGENTS.local.md)
check "CLAUDE.md: untracked content goes private, not public" false (grep -rqF stray-claude $p6/AGENTS.md; and echo true; or echo false)
check "CLAUDE.md: untracked CLAUDE.md removed from the project" false (test -e $p6/CLAUDE.md; and echo true; or echo false)

echo ""
echo "== agents-init: mode flags =="

set -l f1 (new_repo)
pushd $f1 >/dev/null
set -l frc1 (agents-init --public --private --silent 2>/dev/null; echo $status)
popd >/dev/null
check "both flags: usage error" 2 "$frc1"
check "both flags: nothing scaffolded" false (test -e $f1/AGENTS; and echo true; or echo false)

pushd $p1 >/dev/null
set -l frc2 (agents-init --private --silent 2>/dev/null; echo $status)
popd >/dev/null
check "--private on a public project: refused" 1 "$frc2"
check "--private on a public project: still public" public (cat $p1/AGENTS/.mode)

set -l f3 (new_repo)
pushd $f3 >/dev/null
agents-init --private --silent 2>/dev/null
popd >/dev/null
check "--private on a new project: private layout" AGENTS/AGENTS.md (readlink $f3/AGENTS.md)
check "--private on a new project: .mode is private" private (cat $f3/AGENTS/.mode)
check "--private: AGENTS.md ignored, as before" true (_ignored $f3 AGENTS.md)

set -l f4 (new_repo)
mkdir -p $f4/AGENTS
echo legacy >$f4/AGENTS/AGENTS.md
ln -s AGENTS/AGENTS.md $f4/AGENTS.md
pushd $f4 >/dev/null
agents-init --silent 2>/dev/null
popd >/dev/null
check "legacy (no .mode): stays private on a plain run" AGENTS/AGENTS.md (readlink $f4/AGENTS.md)
check "legacy (no .mode): no .mode written" false (test -e $f4/AGENTS/.mode; and echo true; or echo false)

echo ""
echo "== agents-init --public: migrating a private project =="

set -l g1 (new_repo)
echo before >$g1/.gitignore
mkdir -p $g1/sub
echo sub-secret >$g1/sub/AGENTS.md
pushd $g1 >/dev/null
agents-init --private --silent 2>/dev/null
popd >/dev/null
echo root-secret >>$g1/AGENTS/AGENTS.md
git -C $g1 add .gitignore
git -C $g1 commit -qm base
set -l base_head (git -C $g1 rev-parse HEAD)
pushd $g1 >/dev/null
set -l grc (agents-init --public --silent 2>/dev/null; echo $status)
set -l grc2 (agents-init --quiet 2>&1)
popd >/dev/null
check "migrate: exits 0" 0 "$grc"
check "migrate: .mode is public" public (cat $g1/AGENTS/.mode)
check "migrate: root private content moved to AGENTS.local.md" true (grep -qF root-secret $g1/AGENTS/AGENTS.local.md; and echo true; or echo false)
check "migrate: child private content moved to its AGENTS.local.md" sub-secret (cat $g1/AGENTS/sub/AGENTS.local.md)
check "migrate: no private content in any public file" "" (grep -lE 'root-secret|sub-secret' $g1/AGENTS.md $g1/sub/AGENTS.md)
check "migrate: root gets the public starter" (_agents_init_stub --public | string collect) (string collect <$g1/AGENTS.md)
check "migrate: child gets the child starter" (_agents_init_stub --public sub | string collect) (string collect <$g1/sub/AGENTS.md)
check "migrate: history follows the rename" true (test (git -C $g1/AGENTS log --follow --oneline -- AGENTS.local.md | count) -ge 3; and echo true; or echo false)
check "migrate: stub directive retargeted" true (grep -qF '`AGENTS/AGENTS.local.md`' $g1/AGENTS/AGENTS.local.md; and echo true; or echo false)
check "migrate: old directive path gone" false (grep -qF '`AGENTS/AGENTS.md`' $g1/AGENTS/AGENTS.local.md; and echo true; or echo false)
check "migrate: links both ways (root)" "true true" (_is_link $g1/AGENTS.local.md AGENTS/AGENTS.local.md)" "(_is_link $g1/AGENTS/AGENTS.md ../AGENTS.md)
check "migrate: links both ways (child)" "true true" (_is_link $g1/sub/AGENTS.local.md ../AGENTS/sub/AGENTS.local.md)" "(_is_link $g1/AGENTS/sub/AGENTS.md ../../sub/AGENTS.md)
check "migrate: AGENTS.md no longer ignored" false (_ignored $g1 AGENTS.md)
check "migrate: AGENTS.local.md ignored" true (_ignored $g1 AGENTS.local.md)
check "migrate: user .gitignore line kept" true (grep -qx before $g1/.gitignore; and echo true; or echo false)
check "migrate: nothing committed in the project" $base_head (git -C $g1 rev-parse HEAD)
check "migrate: AGENTS/ committed clean" "" (git -C $g1/AGENTS status --porcelain)
check "migrate: re-run is silent" "" "$grc2"

set -l g2 (new_repo)
pushd $g2 >/dev/null
agents-init --private --silent 2>/dev/null
popd >/dev/null
git -C $g2 add -f AGENTS.md 2>/dev/null
pushd $g2 >/dev/null
set -l grc3 (agents-init --public --silent 2>/dev/null; echo $status)
popd >/dev/null
check "migrate refused: staged AGENTS.md change" 1 "$grc3"
check "migrate refused: still private" AGENTS/AGENTS.md (readlink $g2/AGENTS.md)

set -l g3 (new_repo)
pushd $g3 >/dev/null
agents-init --private --silent 2>/dev/null
popd >/dev/null
printf '%s\n' '# user rules' 'AGENTS.md' >>$g3/.gitignore
pushd $g3 >/dev/null
set -l gwarn (agents-init --public 2>&1 >/dev/null | string replace -ra '\e\[[0-9;]*m' '')
popd >/dev/null
check "migrate: a user rule still ignoring AGENTS.md is reported" true (string match -q '*still ignored by a rule outside*' -- $gwarn; and echo true; or echo false)
check "migrate: the user rule is not edited" true (grep -qx 'AGENTS.md' $g3/.gitignore; and echo true; or echo false)

cleanup
report
