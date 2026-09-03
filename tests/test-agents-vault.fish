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

# Describe a path well enough to prove it was not disturbed: a symlink is
# recorded by its literal target (path resolve would hide a link that was
# repointed into a since-deleted temp directory), everything else by kind.
function snapshot_path --argument-names p
    if test -L "$p"
        printf 'link:%s\n' (readlink "$p")
    else if test -d "$p"
        printf 'dir\n'
    else if test -e "$p"
        printf 'file\n'
    else
        printf 'absent\n'
    end
end

#   ────────────────────────── hermeticity floor ──────────────────────────
# agents-vault reads and *writes* global agent state under ~/.claude and
# ~/.gemini when it is not told otherwise, so every run in this file is
# pointed at a throwaway home first. Without this, a test run would copy
# the real agy knowledge store into a temp vault and -- far worse -- move a
# real ~/.claude/memory into a temp directory that cleanup then deletes,
# leaving a dangling symlink behind. Individual sections override these
# with their own fixtures and must restore them here, not erase them.
set -g HERMETIC_HOME (mktemp -d)
set -ga TMPDIRS $HERMETIC_HOME
mkdir -p $HERMETIC_HOME/claude $HERMETIC_HOME/agy
set -g __fish_agent_vault_claude_home $HERMETIC_HOME/claude
set -g __fish_agent_vault_agy_root $HERMETIC_HOME/agy

# Recorded before anything runs, asserted at the very end.
set -g REAL_CLAUDE_MEMORY "$HOME/.claude/memory"
set -g REAL_AGY_ROOT "$HOME/.gemini/antigravity-cli"
set -g REAL_CLAUDE_MEMORY_BEFORE (snapshot_path "$REAL_CLAUDE_MEMORY")
set -g REAL_AGY_ROOT_BEFORE (snapshot_path "$REAL_AGY_ROOT")

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

# Slug sanitization test: special chars in fallback (local-) branch.
set -l dirt (mktemp -d); set -ga TMPDIRS $dirt
mkdir -p "$dirt/projects/My Project!"
git -C "$dirt/projects/My Project!" init -q
git -C "$dirt/projects/My Project!" config user.email t@t
git -C "$dirt/projects/My Project!" config user.name t
set -l slug_dirty (_agents_repo_slug "$dirt/projects/My Project!")
set -l has_bad_chars (string match -q '*[ !]*' -- "$slug_dirty"; and echo true; or echo false)
check "sanitizes special chars in local slug" false "$has_bad_chars"

#   ──────────────────────── ensure_symlink rails ─────────────────────────
echo ""
echo "== _agents_repo_ensure_symlink =="

set -l w (mktemp -d); set -ga TMPDIRS $w
mkdir -p $w/target $w/live

# Fresh link onto an empty live parent.
_agents_repo_ensure_symlink $w/live/memory $w/target >/dev/null
check "creates the link" true (test -L $w/live/memory; and echo true; or echo false)
check "link resolves to target" (path resolve $w/target) (path resolve $w/live/memory)

# Idempotent: a second run prints nothing.
set -l second (_agents_repo_ensure_symlink $w/live/memory $w/target)
check "idempotent, silent" "" "$second"

# Refuses a non-directory target (a symlinked FILE breaks agent edits).
touch $w/afile
check "refuses file target" 1 (_agents_repo_ensure_symlink $w/live/f2 $w/afile 2>/dev/null; echo $status)

# Refuses to create a dangling link when the target is missing.
check "refuses missing target" 1 (_agents_repo_ensure_symlink $w/live/f3 $w/nope 2>/dev/null; echo $status)
check "no dangling link left" false (test -L $w/live/f3; and echo true; or echo false)

# Non-destructive adoption: content on both sides, nothing overwritten.
set -l a (mktemp -d); set -ga TMPDIRS $a
mkdir -p $a/vault $a/live/memory
echo vault-version >$a/vault/shared.md
echo vault-only >$a/vault/vaultonly.md
echo live-version >$a/live/memory/shared.md
echo live-only >$a/live/memory/liveonly.md
_agents_repo_ensure_symlink $a/live/memory $a/vault >/dev/null
check "adoption keeps vault copy" vault-version (cat $a/vault/shared.md)
check "adoption imports live-only file" live-only (cat $a/vault/liveonly.md)
check "adoption keeps vault-only file" vault-only (cat $a/vault/vaultonly.md)
check "adoption replaced dir with link" true (test -L $a/live/memory; and echo true; or echo false)

# Repins a link that points somewhere else.
set -l p (mktemp -d); set -ga TMPDIRS $p
mkdir -p $p/one $p/two
ln -s $p/one $p/link
_agents_repo_ensure_symlink $p/link $p/two >/dev/null
check "repins a wrong link" (path resolve $p/two) (path resolve $p/link)

#   ─────────────────────────── sync policy ───────────────────────────────
echo ""
echo "== _agents_repo_sync =="

set -l s (new_repo)
echo hello >$s/a.md
_agents_repo_sync $s "chore: test" >/dev/null
check "commits new content" 1 (git -C $s rev-list --count HEAD)

# Nothing to do: no second commit, no output.
set -l out (_agents_repo_sync $s "chore: test")
check "idempotent, no new commit" 1 (git -C $s rev-list --count HEAD)
check "idempotent, silent" "" "$out"

# Conflict: two clones diverge with conflicting commits on the same line.
# (Merely leaving "ours" uncommitted in the worktree isn't enough to force
# a rebase conflict -- with nothing local to replay, --autostash's rebase
# step fast-forwards cleanly and only the stash *pop* would conflict,
# leaving "theirs" committed on HEAD with "ours" stranded in the stash.
# Committing "ours" locally first means the rebase itself must replay a
# real commit over "theirs" on the same line, which is where the intended
# conflict-and-abort path actually lives.)
set -l origin (mktemp -d); set -ga TMPDIRS $origin
git -C $origin init -q --bare
git -C $s remote add origin $origin
git -C $s push -q -u origin HEAD:refs/heads/main 2>/dev/null

set -l clone (mktemp -d); set -ga TMPDIRS $clone
git clone -q $origin $clone
git -C $clone config user.email t@t
git -C $clone config user.name t
git -C $clone config commit.gpgsign false
git -C $clone config core.hooksPath /dev/null
echo theirs >$clone/a.md
git -C $clone commit -qam theirs
git -C $clone push -q origin HEAD:main

echo ours >$s/a.md
git -C $s commit -qam ours
set -l before_count (git -C $s rev-list --count HEAD)
set -l rc (_agents_repo_sync $s "chore: test" 2>/dev/null; echo $status)
check "conflict returns 2" 2 "$rc"
check "conflict leaves no rebase in progress" false (test -d $s/.git/rebase-merge -o -d $s/.git/rebase-apply; and echo true; or echo false)
check "conflict commits nothing" $before_count (git -C $s rev-list --count HEAD)
check "conflict content survives" ours (cat $s/a.md)
check "conflict left no markers" false (grep -q '<<<<<<<' $s/a.md; and echo true; or echo false)

# Commit-hook rejection: the commit call itself fails (e.g. a secret
# scanner in a pre-commit hook), distinct from "not a git repository" --
# both currently map to exit 1, so this must not fall through silently or
# report success.
set -l h (new_repo)
echo first >$h/a.md
_agents_repo_sync $h "chore: init" >/dev/null

set -l hooks (mktemp -d); set -ga TMPDIRS $hooks
printf '#!/bin/sh\nexit 1\n' >$hooks/pre-commit
chmod +x $hooks/pre-commit
git -C $h config core.hooksPath $hooks

echo second >$h/a.md
set -l before_hook_count (git -C $h rev-list --count HEAD)
set -l hrc (_agents_repo_sync $h "chore: blocked" 2>/dev/null; echo $status)
check "commit hook rejection returns 1" 1 "$hrc"
check "commit hook rejection commits nothing" $before_hook_count (git -C $h rev-list --count HEAD)

#   ──────────────────────── vault scaffold + link ────────────────────────
echo ""
echo "== agents-vault (scaffold + link) =="

set -l vroot (mktemp -d); set -ga TMPDIRS $vroot
set -l croot (mktemp -d); set -ga TMPDIRS $croot
set -g __fish_agent_vault_dir $vroot/agent-vault
set -g __fish_agent_vault_claude_root $croot

set -l proj (new_repo https://git.rootiest.dev/rootiest/fish-config.git)
set -l pslug git.rootiest.dev-rootiest-fish-config

# Seed a live memory directory the way Claude would.
set -l mangled (string replace -a '/' '-' -- $proj | string replace -a '.' '-')
mkdir -p $croot/$mangled/memory
echo "a memory" >$croot/$mangled/memory/thing.md

pushd $proj >/dev/null
agents-vault --silent
popd >/dev/null

check "vault repo created" true (test -d $vroot/agent-vault/.git; and echo true; or echo false)
check "vault version seeded" 1.0.0 (cat $vroot/agent-vault/.version 2>/dev/null)
check "entry created for slug" true (test -d $vroot/agent-vault/projects/$pslug/claude/memory; and echo true; or echo false)
check "live memory is now a link" true (test -L $croot/$mangled/memory; and echo true; or echo false)
check "memory content preserved" "a memory" (cat $croot/$mangled/memory/thing.md)
check "content lives in the vault" "a memory" (cat $vroot/agent-vault/projects/$pslug/claude/memory/thing.md)
check "origin file written" true (test -f $vroot/agent-vault/projects/$pslug/origin; and echo true; or echo false)
check "vault committed" true (test (git -C $vroot/agent-vault rev-list --count HEAD) -ge 1; and echo true; or echo false)

# Idempotence: a second run prints nothing and adds no commit.
set -l before (git -C $vroot/agent-vault rev-list --count HEAD)
pushd $proj >/dev/null
set -l again (agents-vault --verbose)
popd >/dev/null
check "second run is silent" "" "$again"
check "second run adds no commit" $before (git -C $vroot/agent-vault rev-list --count HEAD)

set -e __fish_agent_vault_dir
set -e __fish_agent_vault_claude_root

#   ─────────────────── emergent restore (vault -> live) ──────────────────
# The reverse of the adoption case above: a vault entry already has curated
# memory (as if cloned from a remote onto a fresh machine) but the live
# Claude project directory does not exist at all yet. agents-vault must
# still create the link so the pre-existing memory is what a starting
# agent sees, rather than silently skipping the link because there was
# nothing local to notice yet.
echo ""
echo "== agents-vault (emergent restore) =="

set -l vroot2 (mktemp -d); set -ga TMPDIRS $vroot2
set -l croot2 (mktemp -d); set -ga TMPDIRS $croot2
set -g __fish_agent_vault_dir $vroot2/agent-vault
set -g __fish_agent_vault_claude_root $croot2

set -l proj2 (new_repo https://git.rootiest.dev/rootiest/agent-vault.git)
set -l pslug2 git.rootiest.dev-rootiest-agent-vault
set -l mangled2 (string replace -a '/' '-' -- $proj2 | string replace -a '.' '-')

# Pre-seed the vault entry the way a cloned vault would already have it.
# Deliberately no $croot2/$mangled2 directory at all -- not even the
# project's own entry, let alone a memory/ subdirectory -- so the fix under
# test is exercised: linking must not depend on the live side existing.
mkdir -p $vroot2/agent-vault/projects/$pslug2/claude/memory
echo "restored memory" >$vroot2/agent-vault/projects/$pslug2/claude/memory/old.md

pushd $proj2 >/dev/null
agents-vault --silent
popd >/dev/null

check "restore: live memory link created with no prior live dir" true (test -L $croot2/$mangled2/memory; and echo true; or echo false)
check "restore: pre-existing vault content readable through the link" "restored memory" (cat $croot2/$mangled2/memory/old.md 2>/dev/null)

set -e __fish_agent_vault_dir
set -e __fish_agent_vault_claude_root

#   ─────────────────── a refused link is reported as failure ─────────────
# _agents_repo_ensure_symlink refuses (exit 1, no stdout) when it cannot
# make the link -- e.g. its mkdir -p of the link's parent directory fails.
# agents-vault must surface that as its own exit 1, not swallow it and
# report success because stdout happened to be empty either way.
echo ""
echo "== agents-vault (link failure surfaces as exit 1) =="

set -l vroot3 (mktemp -d); set -ga TMPDIRS $vroot3
set -l croot3 (mktemp -d); set -ga TMPDIRS $croot3
set -g __fish_agent_vault_dir $vroot3/agent-vault
set -g __fish_agent_vault_claude_root $croot3

set -l proj3 (new_repo https://git.rootiest.dev/rootiest/link-fail-test.git)
set -l mangled3 (string replace -a '/' '-' -- $proj3 | string replace -a '.' '-')

# Make the mangled project path a plain FILE. _agents_repo_ensure_symlink's
# own `mkdir -p (path dirname $link)` then fails outright (ENOTDIR), which
# is exactly the class of failure (permissions, ENOSPC, ...) this guards.
touch $croot3/$mangled3

pushd $proj3 >/dev/null
set -l rc (agents-vault --silent 2>/dev/null; echo $status)
popd >/dev/null

check "link failure: agents-vault exits 1" 1 "$rc"
check "link failure: no link was left behind" false (test -L $croot3/$mangled3/memory; and echo true; or echo false)

set -e __fish_agent_vault_dir
set -e __fish_agent_vault_claude_root

#   ────────────────────────── slug migration ─────────────────────────────
echo ""
echo "== agents-vault (slug migration) =="

set -l vroot2 (mktemp -d); set -ga TMPDIRS $vroot2
set -l croot2 (mktemp -d); set -ga TMPDIRS $croot2
set -g __fish_agent_vault_dir $vroot2/agent-vault
set -g __fish_agent_vault_claude_root $croot2

# Start with no remote, so the project is keyed local-*.
set -l mp (new_repo)
set -l mmangled (string replace -a '/' '-' -- $mp | string replace -a '.' '-')
mkdir -p $croot2/$mmangled/memory
echo "precious" >$croot2/$mmangled/memory/keep.md

pushd $mp >/dev/null
agents-vault --silent
set -l local_slug (_agents_repo_slug $mp)
popd >/dev/null
check "local entry populated" precious (cat $vroot2/agent-vault/projects/$local_slug/claude/memory/keep.md)

# Now add a remote: the slug changes and the entry must migrate.
git -C $mp remote add origin https://git.rootiest.dev/rootiest/later.git
pushd $mp >/dev/null
agents-vault --silent
popd >/dev/null
set -l new_slug git.rootiest.dev-rootiest-later

check "migrated to remote slug" precious (cat $vroot2/agent-vault/projects/$new_slug/claude/memory/keep.md)
check "old entry removed" false (test -d $vroot2/agent-vault/projects/$local_slug; and echo true; or echo false)
check "memory still reachable live" precious (cat $croot2/$mmangled/memory/keep.md)
check "link repinned to new entry" (path resolve $vroot2/agent-vault/projects/$new_slug/claude/memory) (path resolve $croot2/$mmangled/memory)
check "rename recorded in origin" true (grep -q "$local_slug" $vroot2/agent-vault/projects/$new_slug/origin; and echo true; or echo false)

# Ambiguous migration: both entries hold content. Nothing may move.
set -l amb (new_repo)
set -l amangled (string replace -a '/' '-' -- $amb | string replace -a '.' '-')
mkdir -p $croot2/$amangled/memory
echo old >$croot2/$amangled/memory/x.md
pushd $amb >/dev/null
agents-vault --silent
set -l aslug (_agents_repo_slug $amb)
popd >/dev/null

git -C $amb remote add origin https://git.rootiest.dev/rootiest/clash.git
mkdir -p $vroot2/agent-vault/projects/git.rootiest.dev-rootiest-clash/claude/memory
echo new >$vroot2/agent-vault/projects/git.rootiest.dev-rootiest-clash/claude/memory/y.md

pushd $amb >/dev/null
set -l arc (agents-vault --silent 2>/dev/null; echo $status)
popd >/dev/null
check "ambiguous migration fails" 1 "$arc"
check "ambiguous leaves old entry" old (cat $vroot2/agent-vault/projects/$aslug/claude/memory/x.md)
check "ambiguous leaves new entry" new (cat $vroot2/agent-vault/projects/git.rootiest.dev-rootiest-clash/claude/memory/y.md)

# Case 2 of the three required cases: the *current* (new-slug) entry is
# present but empty -- neither absent (handled above) nor holding content
# (the ambiguous case above). Migration must still proceed.
set -l emp (new_repo)
set -l emangled (string replace -a '/' '-' -- $emp | string replace -a '.' '-')
mkdir -p $croot2/$emangled/memory
echo precious2 >$croot2/$emangled/memory/keep.md
pushd $emp >/dev/null
agents-vault --silent
set -l eslug (_agents_repo_slug $emp)
popd >/dev/null

git -C $emp remote add origin https://git.rootiest.dev/rootiest/emptycase.git
set -l enew_slug git.rootiest.dev-rootiest-emptycase
# Pre-create the destination entry as an empty directory -- present, not
# absent -- before migration runs.
mkdir -p $vroot2/agent-vault/projects/$enew_slug/claude/memory

pushd $emp >/dev/null
set -l erc (agents-vault --silent 2>/dev/null; echo $status)
popd >/dev/null
check "empty-current migration succeeds" 0 "$erc"
check "empty-current migrated content" precious2 (cat $vroot2/agent-vault/projects/$enew_slug/claude/memory/keep.md)
check "empty-current old entry removed" false (test -d $vroot2/agent-vault/projects/$eslug; and echo true; or echo false)

# Remote-URL-rewrite transition: origin changes from one forge URL to
# another (distinct from adding a remote where none existed).
set -l rw (new_repo https://git.rootiest.dev/rootiest/rewrite-old.git)
set -l rwmangled (string replace -a '/' '-' -- $rw | string replace -a '.' '-')
mkdir -p $croot2/$rwmangled/memory
echo rewrite-precious >$croot2/$rwmangled/memory/keep.md
pushd $rw >/dev/null
agents-vault --silent
popd >/dev/null
set -l rw_old_slug git.rootiest.dev-rootiest-rewrite-old
check "rewrite: old entry populated" rewrite-precious (cat $vroot2/agent-vault/projects/$rw_old_slug/claude/memory/keep.md)

git -C $rw remote set-url origin https://git.rootiest.dev/rootiest/rewrite-new.git
pushd $rw >/dev/null
agents-vault --silent
popd >/dev/null
set -l rw_new_slug git.rootiest.dev-rootiest-rewrite-new
check "rewrite: migrated to new remote slug" rewrite-precious (cat $vroot2/agent-vault/projects/$rw_new_slug/claude/memory/keep.md)
check "rewrite: old entry removed" false (test -d $vroot2/agent-vault/projects/$rw_old_slug; and echo true; or echo false)

# Remote-removal transition: origin removed, slug reverts to local-*.
set -l rmv (new_repo https://git.rootiest.dev/rootiest/removeme.git)
set -l rmvmangled (string replace -a '/' '-' -- $rmv | string replace -a '.' '-')
mkdir -p $croot2/$rmvmangled/memory
echo removal-precious >$croot2/$rmvmangled/memory/keep.md
pushd $rmv >/dev/null
agents-vault --silent
popd >/dev/null
set -l rmv_remote_slug git.rootiest.dev-rootiest-removeme
check "removal: remote entry populated" removal-precious (cat $vroot2/agent-vault/projects/$rmv_remote_slug/claude/memory/keep.md)

git -C $rmv remote remove origin
pushd $rmv >/dev/null
agents-vault --silent
set -l rmv_local_slug (_agents_repo_slug $rmv)
popd >/dev/null
check "removal: migrated to local slug" removal-precious (cat $vroot2/agent-vault/projects/$rmv_local_slug/claude/memory/keep.md)
check "removal: old remote entry removed" false (test -d $vroot2/agent-vault/projects/$rmv_remote_slug; and echo true; or echo false)

# Fallback-candidate sanitization: a dirty basename (space, !) must produce
# the same local-* slug that _agents_repo_slug would derive, so that a
# lost-symlink recovery (no live link, but the vault entry survives) can
# still find and adopt it. Before the fix, the fallback only lowercased
# the basename instead of sanitizing it like _agents_repo_slug does, so it
# could never match the real entry directory for a name like this.
set -l dirty_root (mktemp -d); set -ga TMPDIRS $dirty_root
set -l dp "$dirty_root/My Project!"
mkdir -p "$dp"
git -C "$dp" init -q
git -C "$dp" config user.email t@t
git -C "$dp" config user.name t
git -C "$dp" config commit.gpgsign false
git -C "$dp" config core.hooksPath /dev/null

set -l dmangled (string replace -a '/' '-' -- $dp | string replace -a '.' '-')
mkdir -p $croot2/$dmangled/memory
echo "dirty-precious" >$croot2/$dmangled/memory/keep.md

pushd $dp >/dev/null
agents-vault --silent
set -l dirty_local_slug (_agents_repo_slug $dp)
popd >/dev/null
check "dirty local entry populated" dirty-precious (cat $vroot2/agent-vault/projects/$dirty_local_slug/claude/memory/keep.md)

# Lose the live symlink, as a fresh-machine restore would, so migration
# must fall back to recomputing the candidate from the path instead of
# reading it off the (now-absent) live symlink.
rm -f $croot2/$dmangled/memory

git -C $dp remote add origin https://git.rootiest.dev/rootiest/dirty.git
pushd $dp >/dev/null
agents-vault --silent
popd >/dev/null
set -l dirty_new_slug git.rootiest.dev-rootiest-dirty
check "fallback finds sanitized local entry" dirty-precious (cat $vroot2/agent-vault/projects/$dirty_new_slug/claude/memory/keep.md)
check "fallback old entry removed" false (test -d $vroot2/agent-vault/projects/$dirty_local_slug; and echo true; or echo false)

set -e __fish_agent_vault_dir
set -e __fish_agent_vault_claude_root

#   ──────────────────────────── global state ─────────────────────────────
# State that belongs to no project: agy's knowledge store and settings.json
# (copied, because agy keys by conversation UUID and its store sits beside
# SQLite databases with WAL sidecars) and Claude's *global* memory
# directory (symlinked, exactly like per-project memory).
echo ""
echo "== agents-vault (global state) =="

set -l vroot5 (mktemp -d); set -ga TMPDIRS $vroot5
set -l croot5 (mktemp -d); set -ga TMPDIRS $croot5
set -l chome5 (mktemp -d); set -ga TMPDIRS $chome5
set -l agy5 (mktemp -d); set -ga TMPDIRS $agy5
set -g __fish_agent_vault_dir $vroot5/agent-vault
set -g __fish_agent_vault_claude_root $croot5
set -g __fish_agent_vault_claude_home $chome5
set -g __fish_agent_vault_agy_root $agy5

mkdir -p $agy5/knowledge $agy5/conversations
echo learned >$agy5/knowledge/fact.md
echo '{"model":"x"}' >$agy5/settings.json
# Decoys that must never be copied: the allowlist names knowledge/ and
# settings.json and nothing else.
echo secret >$agy5/history.jsonl
: >$agy5/conversations/c.db-wal

# A global (non-per-project) Claude memory directory with a sentinel file.
# __fish_agent_vault_claude_home is what keeps this off the real ~/.claude:
# if agents-vault ignored the override, these checks would fail here *and*
# the real global memory would be moved into $chome5.
mkdir -p $chome5/memory
echo global-memory >$chome5/memory/g.md

set -l gp (new_repo https://git.rootiest.dev/rootiest/globals.git)
pushd $gp >/dev/null
agents-vault --silent
popd >/dev/null

check "agy knowledge copied" learned (cat $vroot5/agent-vault/global/agy/knowledge/fact.md)
check "agy settings copied" '{"model":"x"}' (cat $vroot5/agent-vault/global/agy/settings.json)
check "agy knowledge is a copy not a link" false (test -L $vroot5/agent-vault/global/agy/knowledge; and echo true; or echo false)
check "history.jsonl not copied" false (test -e $vroot5/agent-vault/global/agy/history.jsonl; and echo true; or echo false)
check "conversations not copied" false (test -e $vroot5/agent-vault/global/agy/conversations; and echo true; or echo false)

check "global claude memory in the vault" global-memory (cat $vroot5/agent-vault/global/claude/memory/g.md)
check "global claude memory is now a link" true (test -L $chome5/memory; and echo true; or echo false)
check "global link points into the vault" (path resolve $vroot5/agent-vault/global/claude/memory) (path resolve $chome5/memory)
check "global memory readable through the link" global-memory (cat $chome5/memory/g.md)

# --quiet must stay silent when nothing upstream changed. agents-vault runs
# on every claude/agy launch, so a copy step that reported "changed" on
# every run (cp cannot tell whether anything differed) would print a
# summary line at every launch and defeat the flag entirely.
pushd $gp >/dev/null
set -l q1 (agents-vault --quiet)
set -l q2 (agents-vault --quiet)
popd >/dev/null
check "first --quiet rerun prints nothing" "" "$q1"
check "second --quiet rerun prints nothing" "" "$q2"

# ... but a genuine upstream change must still re-sync and still report.
echo "learned more" >$agy5/knowledge/fact.md
pushd $gp >/dev/null
set -l q3 (agents-vault --quiet)
popd >/dev/null
check "agy knowledge re-synced" "learned more" (cat $vroot5/agent-vault/global/agy/knowledge/fact.md)
check "changed agy content reports in --quiet" true (string match -q '*Synced*' -- "$q3"; and echo true; or echo false)

set -e __fish_agent_vault_dir
set -e __fish_agent_vault_claude_root

#   ────────────────── emergent restore of global memory ──────────────────
# The global counterpart of the per-project restore case: a cloned vault
# already carries global/claude/memory but the live ~/.claude/memory does
# not exist yet. The link must still be created, or a starting agent writes
# fresh, history-less global memory beside the restored copy.
echo ""
echo "== agents-vault (global emergent restore) =="

set -l vroot6 (mktemp -d); set -ga TMPDIRS $vroot6
set -l croot6 (mktemp -d); set -ga TMPDIRS $croot6
set -l chome6 (mktemp -d); set -ga TMPDIRS $chome6
set -l agy6 (mktemp -d); set -ga TMPDIRS $agy6
set -g __fish_agent_vault_dir $vroot6/agent-vault
set -g __fish_agent_vault_claude_root $croot6
set -g __fish_agent_vault_claude_home $chome6
set -g __fish_agent_vault_agy_root $agy6

mkdir -p $vroot6/agent-vault/global/claude/memory
echo restored-global >$vroot6/agent-vault/global/claude/memory/old.md

set -l gp6 (new_repo https://git.rootiest.dev/rootiest/globals-restore.git)
pushd $gp6 >/dev/null
agents-vault --silent
popd >/dev/null

check "global restore: link created with no prior live dir" true (test -L $chome6/memory; and echo true; or echo false)
check "global restore: vault content readable through the link" restored-global (cat $chome6/memory/old.md 2>/dev/null)

# A home with neither side populated must not have a memory/ invented for
# it: ~/.claude/memory does not exist by default.
set -l chome7 (mktemp -d); set -ga TMPDIRS $chome7
set -l vroot7 (mktemp -d); set -ga TMPDIRS $vroot7
set -g __fish_agent_vault_dir $vroot7/agent-vault
set -g __fish_agent_vault_claude_home $chome7
set -l gp7 (new_repo https://git.rootiest.dev/rootiest/globals-absent.git)
pushd $gp7 >/dev/null
agents-vault --silent
popd >/dev/null
check "absent global memory is not fabricated" false (test -e $chome7/memory; and echo true; or echo false)

set -e __fish_agent_vault_dir
set -e __fish_agent_vault_claude_root
set -g __fish_agent_vault_claude_home $HERMETIC_HOME/claude
set -g __fish_agent_vault_agy_root $HERMETIC_HOME/agy

#   ────────────── a failed global link must not abort the run ────────────
# The global block runs before the per-project link and before the commit,
# and global memory is optional and frequently absent. A fault there must
# never take the primary per-project backup down with it: otherwise a
# stray file or a permission problem at ~/.claude/memory would break
# memory backup for every project, on every agent launch.
echo ""
echo "== agents-vault (global link failure is non-fatal) =="

set -l vroot8 (mktemp -d); set -ga TMPDIRS $vroot8
set -l croot8 (mktemp -d); set -ga TMPDIRS $croot8
set -l chome8 (mktemp -d); set -ga TMPDIRS $chome8
set -l agy8 (mktemp -d); set -ga TMPDIRS $agy8
set -g __fish_agent_vault_dir $vroot8/agent-vault
set -g __fish_agent_vault_claude_root $croot8
set -g __fish_agent_vault_claude_home $chome8
set -g __fish_agent_vault_agy_root $agy8

# A regular FILE where the global memory directory belongs.
# _agents_repo_ensure_symlink refuses to replace a non-directory, so the
# global link cannot succeed here.
echo not-a-directory >$chome8/memory

# ... while this project has perfectly good memory waiting to be backed up.
set -l fp (new_repo https://git.rootiest.dev/rootiest/globalfail.git)
set -l fslug git.rootiest.dev-rootiest-globalfail
set -l fmangled (string replace -a '/' '-' -- $fp | string replace -a '.' '-')
mkdir -p $croot8/$fmangled/memory
echo project-memory >$croot8/$fmangled/memory/p.md

set -l ferr (mktemp); set -ga TMPDIRS $ferr
pushd $fp >/dev/null
set -l frc (agents-vault --silent 2>$ferr; echo $status)
popd >/dev/null
set -l fwarn (cat $ferr)

check "global link failure: exits 0" 0 "$frc"
check "global link failure: warns on stderr" true (string match -q "*$chome8/memory*" -- "$fwarn"; and echo true; or echo false)
check "global link failure: live file left alone" not-a-directory (cat $chome8/memory)

# The finding itself: the primary, per-project backup must still happen.
check "global link failure: per-project link still created" true (test -L $croot8/$fmangled/memory; and echo true; or echo false)
check "global link failure: per-project memory reached the vault" project-memory (cat $vroot8/agent-vault/projects/$fslug/claude/memory/p.md)
check "global link failure: vault still committed" true (test (git -C $vroot8/agent-vault rev-list --count HEAD) -ge 1; and echo true; or echo false)
check "global link failure: per-project memory is committed" true (git -C $vroot8/agent-vault ls-files --error-unmatch projects/$fslug/claude/memory/p.md >/dev/null 2>&1; and echo true; or echo false)

# A failed global link must not be recorded as done: the next run has to
# re-enter the block and warn again, not treat the vault as correct.
pushd $fp >/dev/null
set -l ferr2 (mktemp); set -ga TMPDIRS $ferr2
agents-vault --silent 2>$ferr2
popd >/dev/null
check "global link failure: retried on the next run" true (string match -q "*$chome8/memory*" -- (cat $ferr2); and echo true; or echo false)

set -e __fish_agent_vault_dir
set -e __fish_agent_vault_claude_root
set -g __fish_agent_vault_claude_home $HERMETIC_HOME/claude
set -g __fish_agent_vault_agy_root $HERMETIC_HOME/agy

#   ──────────────────────── hermeticity assertion ────────────────────────
# The whole suite must never have touched the real global agent state. The
# failure this guards is specific: a global-memory sync with no test
# override would move ~/.claude/memory into a mktemp vault that cleanup
# then deletes, leaving the live path a dangling symlink.
echo ""
echo "== hermeticity =="

check "real ~/.claude/memory untouched" "$REAL_CLAUDE_MEMORY_BEFORE" (snapshot_path "$REAL_CLAUDE_MEMORY")
check "real agy root untouched" "$REAL_AGY_ROOT_BEFORE" (snapshot_path "$REAL_AGY_ROOT")

set -e __fish_agent_vault_claude_home
set -e __fish_agent_vault_agy_root

cleanup
echo ""
echo (math $TESTS_RUN - $TESTS_FAILED)"/$TESTS_RUN passed"
exit $TESTS_FAILED
