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
check "dry-run: plans removing AGENTS/" true (string match -q -- '*remove AGENTS/*' "$dout"; and echo true; or echo false)

cleanup
report
