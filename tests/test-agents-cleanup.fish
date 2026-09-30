#!/usr/bin/env fish
# Copyright (C) 2026 Rootiest
# SPDX-License-Identifier: AGPL-3.0-or-later
#
# Hermetic tests for agents-cleanup: every case builds its own throwaway
# git repo under mktemp, scaffolds it with the real agents-init, and runs
# agents-cleanup against it. XDG_STATE_HOME is a fresh temp dir per case,
# so bundles never land in the real state dir. Nothing touches this
# checkout.
#
# Runs isolated (no `# MODE:` marker, which means isolated).
#
# Usage: fish tests/test-agents-cleanup.fish

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

# A fresh bundle destination per case, so bundle counts never leak.
function fresh_state
    set -gx XDG_STATE_HOME (mktemp -d)
    set -ga TMPDIRS $XDG_STATE_HOME
end

# A project with a user .gitignore line, a root and a scoped AGENTS.md,
# and a real docs/plans -- scaffolded by the real agents-init, so it
# carries every link shape: root and subdir AGENTS.md, docs/plans (the
# original location) and docs/superpowers/plans (its duplicate), and
# docs/superpowers/specs (a .gitkeep-only target).
function scaffolded_repo
    set -l d (new_repo)
    echo keep-me >$d/.gitignore
    echo user-root >$d/AGENTS.md
    mkdir -p $d/functions $d/docs/plans
    echo user-scoped >$d/functions/AGENTS.md
    echo a-plan >$d/docs/plans/p.md
    pushd $d >/dev/null
    agents-init --silent 2>/dev/null
    popd >/dev/null
    printf '%s\n' $d
end

# Content hash of a tree, .git directories excluded: proves a refusal or
# a dry run changed nothing on disk.
function tree_hash --argument-names d
    tar --sort=name --exclude=.git -C $d -cf - . | sha256sum
end

section "agents-cleanup: outside git"
fresh_state
set -l n1 (mktemp -d)
set -a TMPDIRS $n1
pushd $n1 >/dev/null
set -l nrc1 (set -lx GIT_CEILING_DIRECTORIES (path dirname $n1); agents-cleanup --silent 2>/dev/null; echo $status)
set -l nfile1 (test -e $n1/.agents-disabled; and echo true; or echo false)
set -l nrc2 (set -lx GIT_CEILING_DIRECTORIES (path dirname $n1); agents-cleanup --marker-file --silent 2>/dev/null; echo $status)
popd >/dev/null
check "non-git without --marker-file: exits 1" 1 "$nrc1"
check "non-git without --marker-file: writes nothing" false "$nfile1"
check "non-git with --marker-file: exits 0" 0 "$nrc2"
check "non-git with --marker-file: .agents-disabled written" true (test -f $n1/.agents-disabled; and echo true; or echo false)

section "agents-cleanup: never-scaffolded project"
fresh_state
set -l p1 (new_repo)
pushd $p1 >/dev/null
set -l prc (agents-cleanup --silent 2>/dev/null; echo $status)
popd >/dev/null
check "no AGENTS/: exits 0" 0 "$prc"
check "no AGENTS/: git key set" true (git -C $p1 config --type=bool --get agents-init.disabled)
check "no AGENTS/: nothing created" "" (command ls -A $p1 | string match -v .git)

section "agents-cleanup: unlinked files refuse"
fresh_state
set -l x1 (scaffolded_repo)
echo notes >$x1/AGENTS/notes.md
set -l xbefore (tree_hash $x1)
pushd $x1 >/dev/null
set -l xerr (agents-cleanup 2>&1 >/dev/null)
set -l xrc $status
popd >/dev/null
check "extras: exits 1" 1 "$xrc"
check "extras: tree unchanged" "$xbefore" (tree_hash $x1)
check "extras: git key not set" 1 (git -C $x1 config --get agents-init.disabled >/dev/null; echo $status)
check "extras: names the file" true (string match -q -- '*AGENTS/notes.md*' "$xerr"; and echo true; or echo false)

section "agents-cleanup: --dry-run"
fresh_state
set -l d1 (scaffolded_repo)
set -l dbefore (tree_hash $d1)
pushd $d1 >/dev/null
set -l dout (agents-cleanup --dry-run 2>/dev/null)
set -l drc $status
popd >/dev/null
check "dry-run: exits 0" 0 "$drc"
check "dry-run: tree unchanged" "$dbefore" (tree_hash $d1)
check "dry-run: git key not set" 1 (git -C $d1 config --get agents-init.disabled >/dev/null; echo $status)
check "dry-run: plans restoring docs/plans" true (string match -q -- '*restore docs/plans from AGENTS/plans*' "$dout"; and echo true; or echo false)
check "dry-run: plans dropping the duplicate link" true (string match -q -- '*remove link docs/superpowers/plans*' "$dout"; and echo true; or echo false)
check "dry-run: plans dropping the .gitkeep-only link" true (string match -q -- '*remove link docs/superpowers/specs*' "$dout"; and echo true; or echo false)
check "dry-run: plans removing AGENTS/" true (string match -q -- '*remove AGENTS/*' "$dout"; and echo true; or echo false)

section "agents-cleanup: unresolved rebase refuses"
fresh_state
set -l r1 (scaffolded_repo)
mkdir $r1/AGENTS/.git/rebase-merge
set -l rbefore (tree_hash $r1)
pushd $r1 >/dev/null
agents-cleanup >/dev/null 2>&1
set -l rrc $status
popd >/dev/null
check "rebase: exits 1" 1 "$rrc"
check "rebase: tree unchanged" "$rbefore" (tree_hash $r1)
check "rebase: git key not set" 1 (git -C $r1 config --get agents-init.disabled >/dev/null; echo $status)

section "agents-cleanup: --marker-file inside git"
fresh_state
set -l m1 (scaffolded_repo)
pushd $m1 >/dev/null
set -l mout (agents-cleanup --dry-run --marker-file 2>/dev/null)
popd >/dev/null
check "marker dry-run: plans writing the file" true (string match -q -- '*write .agents-disabled*' "$mout"; and echo true; or echo false)
set -l m2 (new_repo)
pushd $m2 >/dev/null
set -l mrc (agents-cleanup --marker-file --silent 2>/dev/null; echo $status)
popd >/dev/null
check "marker run: exits 0" 0 "$mrc"
check "marker run: .agents-disabled written" true (test -f $m2/.agents-disabled; and echo true; or echo false)
check "marker run: git key set" true (git -C $m2 config --type=bool --get agents-init.disabled)

section "agents-cleanup: --dry-run --drop-extras"
fresh_state
set -l e1 (scaffolded_repo)
echo notes >$e1/AGENTS/notes.md
set -l ebefore (tree_hash $e1)
pushd $e1 >/dev/null
set -l eout (agents-cleanup --dry-run --drop-extras 2>/dev/null)
set -l erc $status
popd >/dev/null
check "drop-extras dry-run: exits 0" 0 "$erc"
check "drop-extras dry-run: plans discarding the file" true (string match -q -- '*discard AGENTS/notes.md*' "$eout"; and echo true; or echo false)
check "drop-extras dry-run: tree unchanged" "$ebefore" (tree_hash $e1)

section "agents-cleanup: glob characters in the project path"
fresh_state
set -l g0 (mktemp -d)
set -a TMPDIRS $g0
set -l g1 "$g0/p[x]"
mkdir $g1
git -C $g1 init -q
git -C $g1 config user.email t@t
git -C $g1 config user.name t
git -C $g1 config commit.gpgsign false
git -C $g1 config core.hooksPath /dev/null
echo a-plan >$g1/README.md
pushd $g1 >/dev/null
agents-init --silent 2>/dev/null
set -l gout (agents-cleanup --dry-run 2>/dev/null)
set -l grc $status
popd >/dev/null
check "glob path: AGENTS/ scaffolded" true (test -d $g1/AGENTS/.git; and echo true; or echo false)
check "glob path: dry-run exits 0" 0 "$grc"
check "glob path: plan removes AGENTS/" true (string match -q -- '*remove AGENTS/*' "$gout"; and echo true; or echo false)
check "glob path: plan never lists .git/" false (string match -q -- '*.git/*' "$gout"; and echo true; or echo false)

section "agents-cleanup: full cleanup"
fresh_state
set -l c1 (scaffolded_repo)
pushd $c1 >/dev/null
set -l crc (agents-cleanup --silent 2>/dev/null; echo $status)
popd >/dev/null
check "full: exits 0" 0 "$crc"
check "full: AGENTS/ removed" false (test -e $c1/AGENTS; and echo true; or echo false)
check "full: root AGENTS.md is a real file" false (test -L $c1/AGENTS.md; and echo true; or echo false)
check "full: root content kept" user-root (string collect <$c1/AGENTS.md)
check "full: subdir AGENTS.md real, content kept" user-scoped (test -L $c1/functions/AGENTS.md; or string collect <$c1/functions/AGENTS.md)
check "full: docs/plans restored as a real dir" a-plan (test -L $c1/docs/plans; or string collect <$c1/docs/plans/p.md)
check "full: no .gitkeep in docs/plans" false (test -e $c1/docs/plans/.gitkeep; and echo true; or echo false)
check "full: docs/superpowers removed" false (test -e $c1/docs/superpowers -o -L $c1/docs/superpowers; and echo true; or echo false)
check "full: git key set" true (git -C $c1 config --type=bool --get agents-init.disabled)
check "full: .gitignore keeps only user lines" keep-me (string collect <$c1/.gitignore)
check "full: nothing committed to the outer repo" "" (git -C $c1 rev-list --all 2>/dev/null)
set -l cb $XDG_STATE_HOME/agents-cleanup/*.bundle
check "full: one bundle written" 1 (count $cb)
set -l restored (mktemp -d)
set -a TMPDIRS $restored
git clone -q $cb[1] $restored/AGENTS 2>/dev/null
check "full: bundle restores the history" user-root (string collect <$restored/AGENTS/AGENTS.md)

pushd $c1 >/dev/null
agents-init --silent 2>/dev/null
popd >/dev/null
check "full: agents-init no longer scaffolds" false (test -e $c1/AGENTS; and echo true; or echo false)

pushd $c1 >/dev/null
set -l c2out (agents-cleanup --quiet 2>&1)
set -l c2rc $status
popd >/dev/null
check "rerun: exits 0" 0 "$c2rc"
check "rerun: quiet prints nothing" "" "$c2out"

section "agents-cleanup: stub AGENTS.md"
fresh_state
set -l s1 (new_repo)
pushd $s1 >/dev/null
agents-init --silent 2>/dev/null
agents-cleanup --silent 2>/dev/null
popd >/dev/null
check "stub: deleted" false (test -e $s1/AGENTS.md -o -L $s1/AGENTS.md; and echo true; or echo false)
check "stub: untracked blocks-only .gitignore deleted" false (test -e $s1/.gitignore; and echo true; or echo false)

section "agents-cleanup: tracked blocks-only .gitignore is emptied, not deleted"
fresh_state
set -l g1 (new_repo)
pushd $g1 >/dev/null
agents-init --silent 2>/dev/null
git add .gitignore
git commit -qm gi
agents-cleanup --silent 2>/dev/null
popd >/dev/null
check "tracked .gitignore: still exists" true (test -f $g1/.gitignore; and echo true; or echo false)
check "tracked .gitignore: emptied" "" (string collect <$g1/.gitignore)
check "tracked .gitignore: index untouched (unstaged change only)" " M .gitignore" (git -C $g1 status --porcelain -- .gitignore)

section "agents-cleanup: directive stripped from a user AGENTS.md"
fresh_state
set -l t1 (new_repo)
printf '%s\n' '# Title' '' '> ⚠️ **SYSTEM DIRECTIVE FOR AI AGENTS: FILE EDITING**' '> write to AGENTS/AGENTS.md' '' body >$t1/AGENTS.md
pushd $t1 >/dev/null
agents-init --silent 2>/dev/null
agents-cleanup --silent 2>/dev/null
popd >/dev/null
check "directive: blockquote and its trailing blank line removed" (printf '%s\n' '# Title' '' body | string collect) (string collect <$t1/AGENTS.md)

section "agents-cleanup: --drop-extras"
fresh_state
set -l x2 (scaffolded_repo)
echo notes >$x2/AGENTS/notes.md
pushd $x2 >/dev/null
set -l x2rc (agents-cleanup --drop-extras --silent 2>/dev/null; echo $status)
popd >/dev/null
check "drop-extras: exits 0" 0 "$x2rc"
check "drop-extras: AGENTS/ removed" false (test -e $x2/AGENTS; and echo true; or echo false)
set -l xb $XDG_STATE_HOME/agents-cleanup/*.bundle
set -l xr (mktemp -d)
set -a TMPDIRS $xr
git clone -q $xb[1] $xr/AGENTS 2>/dev/null
check "drop-extras: dropped file is in the bundle" notes (string collect <$xr/AGENTS/notes.md)

section "agents-cleanup: rejected final commit"
fresh_state
set -l f1 (scaffolded_repo)
set -l hooks (mktemp -d)
set -a TMPDIRS $hooks
printf '%s\n' '#!/bin/sh' 'exit 1' >$hooks/pre-commit
chmod +x $hooks/pre-commit
git -C $f1/AGENTS config core.hooksPath $hooks
echo change >>$f1/AGENTS/AGENTS.md
pushd $f1 >/dev/null
set -l frc (agents-cleanup --silent 2>/dev/null; echo $status)
popd >/dev/null
check "rejected commit: exits 1" 1 "$frc"
check "rejected commit: AGENTS/ kept" true (test -d $f1/AGENTS/.git; and echo true; or echo false)
check "rejected commit: root link untouched" AGENTS/AGENTS.md (readlink $f1/AGENTS.md)
set -l fb $XDG_STATE_HOME/agents-cleanup/*.bundle
check "rejected commit: no bundle" 0 (count $fb)

section "agents-cleanup: failed move keeps the link, re-run resumes"
fresh_state
set -l w1 (scaffolded_repo)
chmod a-w $w1/AGENTS/functions
pushd $w1 >/dev/null
set -l w1rc (agents-cleanup --silent 2>/dev/null; echo $status)
popd >/dev/null
check "failed mv: exits 1" 1 "$w1rc"
check "failed mv: link still a symlink" true (test -L $w1/functions/AGENTS.md; and echo true; or echo false)
chmod u+w $w1/AGENTS/functions
pushd $w1 >/dev/null
set -l w2rc (agents-cleanup --silent 2>/dev/null; echo $status)
popd >/dev/null
check "failed mv re-run: exits 0" 0 "$w2rc"
check "failed mv re-run: real file, content kept" user-scoped (test -L $w1/functions/AGENTS.md; or string collect <$w1/functions/AGENTS.md)

section "agents-cleanup: failed directive rewrite keeps AGENTS/"
fresh_state
set -l k1 (new_repo)
printf '%s\n' '# Title' '' '> **SYSTEM DIRECTIVE FOR AI AGENTS: FILE EDITING**' '> x' '' body >$k1/AGENTS.md
pushd $k1 >/dev/null
agents-init --silent 2>/dev/null
popd >/dev/null
chmod a-w $k1/AGENTS/AGENTS.md
pushd $k1 >/dev/null
set -l k1rc (agents-cleanup --silent 2>/dev/null; echo $status)
popd >/dev/null
chmod u+w $k1/AGENTS/AGENTS.md $k1/AGENTS.md 2>/dev/null
check "failed rewrite: exits 1" 1 "$k1rc"
check "failed rewrite: AGENTS/ kept" true (test -d $k1/AGENTS; and echo true; or echo false)

section "agents-cleanup: unterminated .gitignore block is left alone, quietly"
fresh_state
set -l u1 (new_repo)
printf '%s\n' user-line '' '#   ──── Added by agents-init ────' AGENTS/ >$u1/.gitignore
set -l ubefore (string collect <$u1/.gitignore)
pushd $u1 >/dev/null
set -l u1rc (agents-cleanup --silent 2>/dev/null; echo $status)
popd >/dev/null
check "unterminated: exits 0" 0 "$u1rc"
check "unterminated: file byte-identical" "$ubefore" (string collect <$u1/.gitignore)
pushd $u1 >/dev/null
set -l u2out (agents-cleanup --quiet 2>&1)
popd >/dev/null
check "unterminated: quiet re-run prints nothing" "" "$u2out"

section "agents-cleanup: symlinked AGENTS refuses"
fresh_state
set -l l1 (new_repo)
set -l ext (mktemp -d)
set -a TMPDIRS $ext
echo precious >$ext/file
ln -s $ext $l1/AGENTS
pushd $l1 >/dev/null
set -l l1rc (agents-cleanup --silent 2>/dev/null; echo $status)
popd >/dev/null
check "symlinked AGENTS: exits 1" 1 "$l1rc"
check "symlinked AGENTS: target file survives" precious (string collect <$ext/file)

section "agents-cleanup: extras without a bundle"
fresh_state
set -l n2 (new_repo)
mkdir $n2/AGENTS
echo stray >$n2/AGENTS/stray.md
pushd $n2 >/dev/null
set -l n2err (agents-cleanup 2>&1 >/dev/null)
popd >/dev/null
check "no-repo extras: labelled not in bundle" true (string match -q -- '*stray.md  (not in bundle)*' "$n2err"; and echo true; or echo false)
check "no-repo extras: hint does not promise a bundle" false (string match -q -- '*bundle keeps*' "$n2err"; and echo true; or echo false)

section "agents-cleanup: user AGENTS.md variants"
fresh_state
set -l v1 (new_repo)
printf '%s\n' '> ⚠️ **SYSTEM DIRECTIVE FOR AI AGENTS: FILE EDITING**' '> x' >$v1/AGENTS.md
set -l v2 (new_repo)
printf '%s\n' '# Mine' '' 'no directive here' >$v2/AGENTS.md
set -l v2before (string collect <$v2/AGENTS.md)
for v in $v1 $v2
    pushd $v >/dev/null
    agents-init --silent 2>/dev/null
    agents-cleanup --silent 2>/dev/null
    popd >/dev/null
end
check "directive-only: deleted" false (test -e $v1/AGENTS.md -o -L $v1/AGENTS.md; and echo true; or echo false)
check "no directive: content identical" "$v2before" (string collect <$v2/AGENTS.md)

section "agents-cleanup: invalid AGENTS/.git never commits the outer repo"
fresh_state
set -l i1 (scaffolded_repo)
echo secret >$i1/untracked-secret.txt
rm -rf $i1/AGENTS/.git/HEAD $i1/AGENTS/.git/objects
set -l i1before (git -C $i1 rev-list --all | count)
pushd $i1 >/dev/null
set -l i1rc (agents-cleanup --silent 2>/dev/null; echo $status)
popd >/dev/null
check "invalid .git: exits 0" 0 "$i1rc"
check "invalid .git: outer repo untouched" "$i1before" (git -C $i1 rev-list --all | count)
check "invalid .git: no bundle" 0 (count $XDG_STATE_HOME/agents-cleanup/*.bundle 2>/dev/null)
check "invalid .git: AGENTS/ removed" false (test -e $i1/AGENTS; and echo true; or echo false)

cleanup
report
