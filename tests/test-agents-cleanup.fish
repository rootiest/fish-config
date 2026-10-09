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
# No user or system config: a developer's global hooks, signing or
# init.defaultBranch must not reach these repos.
set -gx GIT_CONFIG_GLOBAL /dev/null
set -gx GIT_CONFIG_NOSYSTEM 1
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
    agents-init --private --silent 2>/dev/null
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
agents-init --private --silent 2>/dev/null
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
agents-init --private --silent 2>/dev/null
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
agents-init --private --silent 2>/dev/null
agents-cleanup --silent 2>/dev/null
popd >/dev/null
check "stub: deleted" false (test -e $s1/AGENTS.md -o -L $s1/AGENTS.md; and echo true; or echo false)
check "stub: untracked blocks-only .gitignore deleted" false (test -e $s1/.gitignore; and echo true; or echo false)

section "agents-cleanup: tracked blocks-only .gitignore is emptied, not deleted"
fresh_state
set -l g1 (new_repo)
pushd $g1 >/dev/null
agents-init --private --silent 2>/dev/null
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
agents-init --private --silent 2>/dev/null
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
if test (id -u) -eq 0
    echo "  SKIP  failed move: chmod cannot block root"
else
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
end

section "agents-cleanup: failed directive rewrite keeps AGENTS/"
fresh_state
if test (id -u) -eq 0
    echo "  SKIP  failed rewrite: chmod cannot block root"
else
    set -l k1 (new_repo)
    printf '%s\n' '# Title' '' '> **SYSTEM DIRECTIVE FOR AI AGENTS: FILE EDITING**' '> x' '' body >$k1/AGENTS.md
    pushd $k1 >/dev/null
    agents-init --private --silent 2>/dev/null
    popd >/dev/null
    chmod a-w $k1/AGENTS/AGENTS.md
    pushd $k1 >/dev/null
    set -l k1rc (agents-cleanup --silent 2>/dev/null; echo $status)
    popd >/dev/null
    chmod u+w $k1/AGENTS/AGENTS.md $k1/AGENTS.md 2>/dev/null
    check "failed rewrite: exits 1" 1 "$k1rc"
    check "failed rewrite: AGENTS/ kept" true (test -d $k1/AGENTS; and echo true; or echo false)
end

section "agents-cleanup: unterminated .gitignore block is left alone, quietly"
fresh_state
set -l u1 (new_repo)
printf '%s\n' user-line '' '#   ──── Added by agents-init ────' AGENTS/ >$u1/.gitignore
# A byte snapshot: `string collect` strips trailing newlines, so a captured
# string could not see a lost or added one.
set -l ubefore (mktemp)
set -a TMPDIRS $ubefore
command cp -f $u1/.gitignore $ubefore
pushd $u1 >/dev/null
set -l u1rc (agents-cleanup --silent 2>/dev/null; echo $status)
popd >/dev/null
check "unterminated: exits 0" 0 "$u1rc"
check "unterminated: file byte-identical" true (cmp -s $ubefore $u1/.gitignore; and echo true; or echo false)
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
set -l v2before (mktemp)
set -a TMPDIRS $v2before
command cp -f $v2/AGENTS.md $v2before
for v in $v1 $v2
    pushd $v >/dev/null
    agents-init --private --silent 2>/dev/null
    agents-cleanup --silent 2>/dev/null
    popd >/dev/null
end
check "directive-only: deleted" false (test -e $v1/AGENTS.md -o -L $v1/AGENTS.md; and echo true; or echo false)
check "no directive: content identical" true (cmp -s $v2before $v2/AGENTS.md; and echo true; or echo false)

section "agents-cleanup: invalid AGENTS/.git never commits the outer repo"
fresh_state
set -l i1 (scaffolded_repo)
echo secret >$i1/untracked-secret.txt
rm -rf $i1/AGENTS/.git/HEAD $i1/AGENTS/.git/objects
set -l i1before (git -C $i1 rev-list --all | count)
pushd $i1 >/dev/null
set -l i1rc (agents-cleanup --silent --force 2>/dev/null; echo $status)
popd >/dev/null
check "invalid .git: exits 0" 0 "$i1rc"
check "invalid .git: outer repo untouched" "$i1before" (git -C $i1 rev-list --all | count)
check "invalid .git: no bundle" 0 (count $XDG_STATE_HOME/agents-cleanup/*.bundle 2>/dev/null)
check "invalid .git: AGENTS/ removed" false (test -e $i1/AGENTS; and echo true; or echo false)

section "agents-cleanup: damaged AGENTS/.git is refused without --force"
fresh_state
set -l d1 (scaffolded_repo)
rm -rf $d1/AGENTS/.git/HEAD $d1/AGENTS/.git/objects
set -l d1err (mktemp)
set -a TMPDIRS $d1err
pushd $d1 >/dev/null
agents-cleanup --quiet 2>$d1err >/dev/null
set -l d1rc $status
popd >/dev/null
check "damaged .git: refused (exit 1)" 1 "$d1rc"
check "damaged .git: stderr names the damage and --force" true (string match -q -- '*damaged*--force*' (string collect <$d1err); and echo true; or echo false)
check "damaged .git: AGENTS/ left in place" true (test -e $d1/AGENTS; and echo true; or echo false)
check "damaged .git: no bundle" 0 (count $XDG_STATE_HOME/agents-cleanup/*.bundle 2>/dev/null)

# --silent suppresses everything but errors, and a refusal is an error.
set -l d2 (scaffolded_repo)
rm -rf $d2/AGENTS/.git/HEAD $d2/AGENTS/.git/objects
set -l d2out (pushd $d2 >/dev/null; agents-cleanup --silent 2>&1; echo "rc=$status"; popd >/dev/null)
check "damaged .git: --silent still reports the refusal" true (string match -q -- '*damaged*' (string join \n -- $d2out); and echo true; or echo false)
check "damaged .git: --silent refusal exits 1" true (string match -q -- '*rc=1*' (string join \n -- $d2out); and echo true; or echo false)
check "damaged .git: --silent leaves AGENTS/ in place" true (test -e $d2/AGENTS; and echo true; or echo false)

# --dry-run refuses the same way, unless --force is also given.
set -l d3 (scaffolded_repo)
rm -rf $d3/AGENTS/.git/HEAD $d3/AGENTS/.git/objects
pushd $d3 >/dev/null
agents-cleanup --dry-run >/dev/null 2>&1
set -l d3rc $status
agents-cleanup --dry-run --force >/dev/null 2>&1
set -l d3frc $status
popd >/dev/null
check "damaged .git: --dry-run refuses" 1 "$d3rc"
check "damaged .git: --dry-run --force exits 0" 0 "$d3frc"
check "damaged .git: --dry-run --force changes nothing" true (test -e $d3/AGENTS; and echo true; or echo false)

section "agents-cleanup: damaged AGENTS/.git with --force is announced, not archived"
fresh_state
set -l i2 (scaffolded_repo)
rm -rf $i2/AGENTS/.git/HEAD $i2/AGENTS/.git/objects
set -l i3 (scaffolded_repo)
rm -rf $i3/AGENTS/.git/HEAD $i3/AGENTS/.git/objects
set -l i2err (mktemp)
set -a TMPDIRS $i2err
pushd $i2 >/dev/null
agents-cleanup --quiet --force 2>$i2err >/dev/null
set -l i2rc $status
popd >/dev/null
set -l i3out (pushd $i3 >/dev/null; agents-cleanup --silent --force 2>&1; popd >/dev/null)
check "damaged .git, --force: exits 0" 0 "$i2rc"
check "damaged .git, --force: stderr says damaged, not archived" true (string match -q -- '*damaged*not archived*' (string collect <$i2err); and echo true; or echo false)
check "damaged .git, --force: no bundle" 0 (count $XDG_STATE_HOME/agents-cleanup/*.bundle 2>/dev/null)
check "damaged .git, --force: AGENTS/ removed" false (test -e $i2/AGENTS; and echo true; or echo false)
check "damaged .git, --force: --silent prints nothing" "" "$i3out"

section "agents-cleanup: verbose output survives a log-file stderr"
fresh_state
set -l o1 (scaffolded_repo)
set -l o1log (mktemp)
set -a TMPDIRS $o1log
# A subshell: only a shell whose own stderr is the file reproduces the
# truncation (an in-process redirect is emulated and never reopens it).
fish --no-config -c "set -p fish_function_path "(string escape -- $repo_root/functions)"; cd "(string escape -- $o1)"; agents-cleanup" >$o1log 2>&1
check "log file: archive line kept" true (string match -q -- '*Archived AGENTS/ history*' (string collect <$o1log); and echo true; or echo false)
check "log file: restore hint kept" true (string match -q -- '*restore with: git clone*' (string collect <$o1log); and echo true; or echo false)

section "agents-cleanup: nested repository under AGENTS/ is never dropped"
fresh_state
set -l q1 (scaffolded_repo)
mkdir -p $q1/AGENTS/scratch/tool
git -C $q1/AGENTS/scratch/tool init -q
echo precious >$q1/AGENTS/scratch/tool/file.txt
set -l q1before (tree_hash $q1)
pushd $q1 >/dev/null
set -l q1err (agents-cleanup --drop-extras 2>&1 >/dev/null)
set -l q1rc $status
popd >/dev/null
check "nested repo: exits 1 even with --drop-extras" 1 "$q1rc"
check "nested repo: tree unchanged" "$q1before" (tree_hash $q1)
check "nested repo: file survives" precious (string collect <$q1/AGENTS/scratch/tool/file.txt)
check "nested repo: message names it" true (string match -q -- '*AGENTS/scratch/tool/*nested repository*' "$q1err"; and echo true; or echo false)
check "nested repo: git key not set" 1 (git -C $q1 config --get agents-init.disabled >/dev/null; echo $status)

section "agents-cleanup: a link to AGENTS/ itself is dropped, not moved"
fresh_state
set -l z1 (scaffolded_repo)
ln -s ../AGENTS $z1/docs/agents
pushd $z1 >/dev/null
set -l z1rc (agents-cleanup --silent 2>/dev/null; echo $status)
popd >/dev/null
check "self link: exits 0" 0 "$z1rc"
check "self link: docs/agents gone" false (test -e $z1/docs/agents -o -L $z1/docs/agents; and echo true; or echo false)
check "self link: docs/plans restored real" a-plan (test -L $z1/docs/plans; or string collect <$z1/docs/plans/p.md)

section "agents-cleanup: AGENTS/ deleted by hand, dangling links still go"
fresh_state
set -l h1 (scaffolded_repo)
rm -rf $h1/AGENTS
pushd $h1 >/dev/null
set -l h1dry (agents-cleanup --dry-run 2>/dev/null)
set -l h1rc (agents-cleanup --silent 2>/dev/null; echo $status)
popd >/dev/null
check "no AGENTS/, dangling: dry-run plans removing links" true (string match -q -- '*remove link AGENTS.md*' "$h1dry"; and echo true; or echo false)
check "no AGENTS/, dangling: exits 0" 0 "$h1rc"
check "no AGENTS/, dangling: AGENTS.md link gone" false (test -e $h1/AGENTS.md -o -L $h1/AGENTS.md; and echo true; or echo false)
check "no AGENTS/, dangling: docs/superpowers gone" false (test -e $h1/docs/superpowers -o -L $h1/docs/superpowers; and echo true; or echo false)
check "no AGENTS/, dangling: git key set" true (git -C $h1 config --type=bool --get agents-init.disabled)

section "agents-cleanup: outside git, no AGENTS/ here: links are not inventoried"
fresh_state
set -l b1 (mktemp -d)
set -a TMPDIRS $b1
mkdir -p $b1/sub
ln -s ../AGENTS/x $b1/sub/dangling
pushd $b1 >/dev/null
set -l b1rc (set -lx GIT_CEILING_DIRECTORIES (path dirname $b1); agents-cleanup --marker-file --silent 2>/dev/null; echo $status)
popd >/dev/null
check "non-git no AGENTS/: exits 0" 0 "$b1rc"
check "non-git no AGENTS/: stray link untouched" true (test -L $b1/sub/dangling; and echo true; or echo false)

section "agents-cleanup: quiet summary carries the restore command"
fresh_state
set -l y1 (scaffolded_repo)
pushd $y1 >/dev/null
set -l y1out (agents-cleanup --quiet 2>&1)
popd >/dev/null
check "quiet: names the restore command" true (string match -q -- '*git clone *.bundle AGENTS*' "$y1out"; and echo true; or echo false)

section "agents-cleanup: user .gitignore lines around two agents-init blocks"
fresh_state
set -l w9 (new_repo)
pushd $w9 >/dev/null
agents-init --private --silent 2>/dev/null
popd >/dev/null
set -l blk (string collect <$w9/.gitignore)
printf '%s\n' before1 before2 >$w9/.gitignore
printf '%s\n' "$blk" >>$w9/.gitignore
printf '%s\n' between >>$w9/.gitignore
printf '%s\n' "$blk" >>$w9/.gitignore
printf '%s\n' after1 after2 >>$w9/.gitignore
pushd $w9 >/dev/null
agents-cleanup --silent 2>/dev/null
popd >/dev/null
check "gitignore: exactly the user lines remain, in order" true (printf '%s\n' before1 before2 between after1 after2 | cmp -s - $w9/.gitignore; and echo true; or echo false)

section "agents-cleanup: public mode keeps public files and private ones unpublished"
fresh_state
set -l pub (new_repo)
mkdir -p $pub/sub
echo sub-public >$pub/sub/AGENTS.md
pushd $pub >/dev/null
agents-init --silent 2>/dev/null
popd >/dev/null
echo root-secret >>$pub/AGENTS/AGENTS.local.md
echo sub-secret >$pub/AGENTS/sub/AGENTS.local.md
pushd $pub >/dev/null
agents-init --silent 2>/dev/null
set -l prc (agents-cleanup --silent 2>&1; echo $status)
popd >/dev/null
check "public cleanup: exits 0 (outward links and .mode are not extras)" 0 "$prc"
check "public cleanup: AGENTS/ removed" false (test -e $pub/AGENTS; and echo true; or echo false)
check "public cleanup: root public file untouched" (_agents_init_stub --public | string collect) (string collect <$pub/AGENTS.md)
check "public cleanup: child public file untouched" sub-public (cat $pub/sub/AGENTS.md)
check "public cleanup: root private file restored as a real file" true (test -f $pub/AGENTS.local.md -a ! -L $pub/AGENTS.local.md; and grep -qF root-secret $pub/AGENTS.local.md; and echo true; or echo false)
check "public cleanup: its directive stripped" false (grep -qF 'SYSTEM DIRECTIVE' $pub/AGENTS.local.md; and echo true; or echo false)
check "public cleanup: child private file restored" sub-secret (cat $pub/sub/AGENTS.local.md)
check "public cleanup: root private file still ignored" 0 (git -C $pub check-ignore -q --no-index AGENTS.local.md; echo $status)
check "public cleanup: child private file still ignored" 0 (git -C $pub check-ignore -q --no-index sub/AGENTS.local.md; echo $status)
check "public cleanup: no agents-init block left" false (grep -q 'Added by agents-init' $pub/.gitignore; and echo true; or echo false)
check "public cleanup: private files never offered to git" "" (git -C $pub status --porcelain --untracked-files=all | string match '*AGENTS.local.md')

fresh_state
set -l pub2 (new_repo)
pushd $pub2 >/dev/null
agents-init --silent 2>/dev/null
agents-cleanup --silent 2>/dev/null
popd >/dev/null
check "public cleanup: an untouched local stub is deleted, not restored" false (test -e $pub2/AGENTS.local.md; and echo true; or echo false)
check "public cleanup: no ignore line needed then" false (test -f $pub2/.gitignore; and grep -qx AGENTS.local.md $pub2/.gitignore; and echo true; or echo false)

cleanup
report
