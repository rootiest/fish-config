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

# A diverged upstream is no longer this function's business. It commits
# locally and never fetches, so neither divergence nor an unreachable
# remote may stop the commit -- that is the entire offline-backup
# guarantee, and the old pull-first shape broke it: a failed fetch took
# the local commit down with it. The divergence is still built here so
# that guarantee is tested against the case that used to fail.
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
set -l before_count (git -C $s rev-list --count HEAD)
set -l rc (_agents_repo_sync $s "chore: test" >/dev/null 2>/dev/null; echo $status)
check "diverged upstream still commits" 0 "$rc"
check "diverged upstream recorded the commit" (math $before_count + 1) (git -C $s rev-list --count HEAD)
check "diverged upstream kept our content" ours (cat $s/a.md)
check "diverged upstream left no markers" false (grep -q '<<<<<<<' $s/a.md; and echo true; or echo false)
check "diverged upstream started no rebase" false (test -d $s/.git/rebase-merge -o -d $s/.git/rebase-apply; and echo true; or echo false)

# An unreachable remote is a non-event for the same reason. A bogus local
# path is used rather than a real unroutable host: it fails instantly
# instead of waiting out a DNS timeout, and the code path being asserted
# is that there is no network code path at all.
git -C $s remote set-url origin /nonexistent/unreachable.git
echo offline >$s/b.md
set -l ocount (git -C $s rev-list --count HEAD)
set -l orc (_agents_repo_sync $s "chore: offline" >/dev/null 2>/dev/null; echo $status)
check "unreachable upstream still commits" 0 "$orc"
check "unreachable upstream recorded the commit" (math $ocount + 1) (git -C $s rev-list --count HEAD)
check "unreachable upstream captured the new file" offline (git -C $s show HEAD:b.md 2>/dev/null)

# The one case that must still refuse: a rebase genuinely in progress. The
# worktree then holds conflict markers and committing them under a routine
# message buries the conflict instead of reporting it. It is left standing
# rather than aborted -- this function did not start it, so it is not its
# to throw away.
git -C $s remote set-url origin $origin
git -C $s -c core.hooksPath=/dev/null pull --rebase -q >/dev/null 2>&1
check "fixture really left a rebase in progress" true (test -d $s/.git/rebase-merge -o -d $s/.git/rebase-apply; and echo true; or echo false)
set -l rrc (_agents_repo_sync $s "chore: blocked" 2>/dev/null; echo $status)
check "in-progress rebase returns 2" 2 "$rrc"
check "in-progress rebase recorded no commit" false (git -C $s log --all --pretty=%s 2>/dev/null | grep -qx 'chore: blocked'; and echo true; or echo false)
check "in-progress rebase is left standing" true (test -d $s/.git/rebase-merge -o -d $s/.git/rebase-apply; and echo true; or echo false)
git -C $s rebase --abort >/dev/null 2>&1

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
# Built the way git itself would leave it, which is the only shape that
# matters here: git cannot track an empty directory, so an entry committed
# while its memory was empty comes back from a clone as projects/<slug>/
# origin and nothing else -- no claude/ subtree at all. Hand-building it
# with claude/memory/ instead (as this fixture used to) tests a shape the
# recovery path never produces, and hid a migration that moved the old
# entry *inside* the new one while still returning 0. The equivalent
# hand-built shape is covered separately just below.
mkdir -p $vroot2/agent-vault/projects/$enew_slug
printf 'remote: %s\npath:   %s\nhost:   %s\n' \
    https://git.rootiest.dev/rootiest/emptycase.git /gone/elsewhere othermachine \
    >$vroot2/agent-vault/projects/$enew_slug/origin

pushd $emp >/dev/null
set -l erc (agents-vault --silent 2>/dev/null; echo $status)
popd >/dev/null
check "empty-current migration succeeds" 0 "$erc"
check "empty-current migrated content" precious2 (cat $vroot2/agent-vault/projects/$enew_slug/claude/memory/keep.md)
check "empty-current old entry removed" false (test -d $vroot2/agent-vault/projects/$eslug; and echo true; or echo false)
check "empty-current did not nest the old entry" false (test -d $vroot2/agent-vault/projects/$enew_slug/$eslug; and echo true; or echo false)
check "empty-current memory reachable live" precious2 (cat $croot2/$emangled/memory/keep.md)
# The destination's origin log is real provenance -- a clone always has
# one -- so it is folded in rather than deleted along with the directory.
check "empty-current kept the destination provenance" true (grep -q othermachine $vroot2/agent-vault/projects/$enew_slug/origin; and echo true; or echo false)

# The other "present but empty" shape, for completeness: claude/memory/
# exists and is empty. Only a hand-built vault looks like this, but the
# guard has to cover it too.
set -l em2 (new_repo)
set -l em2mangled (string replace -a '/' '-' -- $em2 | string replace -a '.' '-')
mkdir -p $croot2/$em2mangled/memory
echo precious3 >$croot2/$em2mangled/memory/keep.md
pushd $em2 >/dev/null
agents-vault --silent
set -l em2slug (_agents_repo_slug $em2)
popd >/dev/null

git -C $em2 remote add origin https://git.rootiest.dev/rootiest/emptydir.git
set -l em2new git.rootiest.dev-rootiest-emptydir
mkdir -p $vroot2/agent-vault/projects/$em2new/claude/memory

pushd $em2 >/dev/null
set -l em2rc (agents-vault --silent 2>/dev/null; echo $status)
popd >/dev/null
check "empty-memory-dir migration succeeds" 0 "$em2rc"
check "empty-memory-dir migrated content" precious3 (cat $vroot2/agent-vault/projects/$em2new/claude/memory/keep.md)
check "empty-memory-dir did not nest the old entry" false (test -d $vroot2/agent-vault/projects/$em2new/$em2slug; and echo true; or echo false)
check "empty-memory-dir memory reachable live" precious3 (cat $croot2/$em2mangled/memory/keep.md)

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

# Same fallback path, but the live memory directory is a real populated
# directory rather than a symlink -- the shape a machine ends up in when
# an agent wrote memory while the link was missing. The migration then
# tries to clear the live path out of the relink's way, and clearing a
# directory is not something it may do: that is somebody's memory, and
# _agents_repo_ensure_symlink already folds it into the vault without
# clobbering. Refusing is therefore correct, but refusing in rm's voice
# is not: a --silent run that did the right thing and returned 0 still
# printed "rm: cannot remove ...: Is a directory", which is the only
# thing the user sees and reads as a failure.
set -l real_root (mktemp -d); set -ga TMPDIRS $real_root
set -l rp "$real_root/proj"
mkdir -p "$rp"
git -C "$rp" init -q
git -C "$rp" config user.email t@t
git -C "$rp" config user.name t
git -C "$rp" config commit.gpgsign false
git -C "$rp" config core.hooksPath /dev/null

set -l rmangled (string replace -a '/' '-' -- $rp | string replace -a '.' '-')
mkdir -p $croot2/$rmangled/memory
echo "banked" >$croot2/$rmangled/memory/old.md

pushd $rp >/dev/null
agents-vault --silent
set -l real_local_slug (_agents_repo_slug $rp)
popd >/dev/null

# Replace the link with a real directory holding memory the vault has
# never seen, then change the slug so the migration runs.
rm -f $croot2/$rmangled/memory
mkdir -p $croot2/$rmangled/memory
echo "written-live" >$croot2/$rmangled/memory/fresh.md
git -C $rp remote add origin https://git.rootiest.dev/rootiest/realdir.git

set -l rerr (mktemp); set -ga TMPDIRS $rerr
pushd $rp >/dev/null
set -l real_rc (agents-vault --silent 2>$rerr; echo $status)
popd >/dev/null
set -l real_err (cat $rerr)
set -l real_new_slug git.rootiest.dev-rootiest-realdir
check "real-directory migration succeeds" 0 "$real_rc"
check "real-directory migration stays silent" "" "$real_err"
check "real-directory migration keeps banked memory" banked (cat $vroot2/agent-vault/projects/$real_new_slug/claude/memory/old.md 2>/dev/null)
check "real-directory migration keeps live memory" written-live (cat $vroot2/agent-vault/projects/$real_new_slug/claude/memory/fresh.md 2>/dev/null)
check "real-directory migration relinks" true (test -L $croot2/$rmangled/memory; and echo true; or echo false)
check "real-directory old entry removed" false (test -d $vroot2/agent-vault/projects/$real_local_slug; and echo true; or echo false)

set -e __fish_agent_vault_dir
set -e __fish_agent_vault_claude_root

#   ───────────────────────── a real git clone ────────────────────────────
# Every other fixture in this file is hand-built, and a hand-built
# directory can have a shape git itself would never produce. That blind
# spot has now shipped two bugs. So this section builds its vault the way
# the feature's own advertised recovery path does -- run the tool, let it
# commit, then clone the result with git -- and runs agents-vault against
# the clone.
echo ""
echo "== agents-vault (a real git clone) =="

#  Machine A: populate a vault and let agents-vault commit it.
set -l cl_vroot (mktemp -d); set -ga TMPDIRS $cl_vroot
set -l cl_croot (mktemp -d); set -ga TMPDIRS $cl_croot
set -g __fish_agent_vault_dir $cl_vroot/agent-vault
set -g __fish_agent_vault_claude_root $cl_croot

# Two projects: one whose memory holds a file at commit time, one whose
# memory is empty. The empty one is the interesting case -- git cannot
# track an empty directory, so its entry survives the clone as origin and
# nothing else.
set -l cl_full (new_repo https://git.rootiest.dev/rootiest/clone-full.git)
set -l cl_full_slug git.rootiest.dev-rootiest-clone-full
set -l cl_full_mangled (string replace -a '/' '-' -- $cl_full | string replace -a '.' '-')
mkdir -p $cl_croot/$cl_full_mangled/memory
echo cloned-memory >$cl_croot/$cl_full_mangled/memory/keep.md
pushd $cl_full >/dev/null
agents-vault --silent
popd >/dev/null

set -l cl_empty (new_repo https://git.rootiest.dev/rootiest/clone-empty.git)
set -l cl_empty_slug git.rootiest.dev-rootiest-clone-empty
pushd $cl_empty >/dev/null
agents-vault --silent
popd >/dev/null

#  The clone, exactly as the README tells a user to make it.
set -l cl_new (mktemp -d); set -ga TMPDIRS $cl_new
git clone -q $cl_vroot/agent-vault $cl_new/agent-vault
git -C $cl_new/agent-vault config user.email t@t
git -C $cl_new/agent-vault config user.name t
git -C $cl_new/agent-vault config commit.gpgsign false

check "clone: the populated entry came back whole" cloned-memory (cat $cl_new/agent-vault/projects/$cl_full_slug/claude/memory/keep.md 2>/dev/null)
check "clone: the empty entry has no claude/ subtree" false (test -d $cl_new/agent-vault/projects/$cl_empty_slug/claude; and echo true; or echo false)
check "clone: the empty entry is its origin file alone" true (test -f $cl_new/agent-vault/projects/$cl_empty_slug/origin; and echo true; or echo false)

#  Machine B, case 1: an ordinary run against the clone restores memory.
set -l cl_croot2 (mktemp -d); set -ga TMPDIRS $cl_croot2
set -g __fish_agent_vault_dir $cl_new/agent-vault
set -g __fish_agent_vault_claude_root $cl_croot2

set -l cl_proj (new_repo https://git.rootiest.dev/rootiest/clone-full.git)
set -l cl_proj_mangled (string replace -a '/' '-' -- $cl_proj | string replace -a '.' '-')
pushd $cl_proj >/dev/null
set -l cl_rc (agents-vault --silent 2>/dev/null; echo $status)
popd >/dev/null
check "clone: an ordinary run against the clone returns 0" 0 "$cl_rc"
check "clone: the live memory became a link" true (test -L $cl_croot2/$cl_proj_mangled/memory; and echo true; or echo false)
check "clone: memory is reachable through the live link" cloned-memory (cat $cl_croot2/$cl_proj_mangled/memory/keep.md 2>/dev/null)

#  Machine B, case 2: migrating onto the clone-shaped entry. The project
#  starts with no remote (keyed local-*); adding the remote the clone's
#  empty entry belongs to points the migration straight at the origin-only
#  directory git produced. This is the case that used to move the old entry
#  *inside* the new one, fabricate a fresh empty memory directory over it,
#  pin the live link to that, and return 0 -- stranding the real memory
#  one level below where --status and --restore ever look.
set -l cl_mig (new_repo)
set -l cl_mig_mangled (string replace -a '/' '-' -- $cl_mig | string replace -a '.' '-')
mkdir -p $cl_croot2/$cl_mig_mangled/memory
echo clone-precious >$cl_croot2/$cl_mig_mangled/memory/keep.md
pushd $cl_mig >/dev/null
agents-vault --silent
set -l cl_mig_slug (_agents_repo_slug $cl_mig)
popd >/dev/null
check "clone: the local entry was populated first" clone-precious (cat $cl_new/agent-vault/projects/$cl_mig_slug/claude/memory/keep.md 2>/dev/null)

git -C $cl_mig remote add origin https://git.rootiest.dev/rootiest/clone-empty.git
pushd $cl_mig >/dev/null
set -l cl_mrc (agents-vault --silent 2>/dev/null; echo $status)
popd >/dev/null
check "clone: migration onto a cloned entry returns 0" 0 "$cl_mrc"
check "clone: migrated memory is reachable through the live link" clone-precious (cat $cl_croot2/$cl_mig_mangled/memory/keep.md 2>/dev/null)
check "clone: migrated memory landed in the new entry" clone-precious (cat $cl_new/agent-vault/projects/$cl_empty_slug/claude/memory/keep.md 2>/dev/null)
check "clone: the old entry was not nested inside the new one" false (test -d $cl_new/agent-vault/projects/$cl_empty_slug/$cl_mig_slug; and echo true; or echo false)
check "clone: the old entry is gone" false (test -d $cl_new/agent-vault/projects/$cl_mig_slug; and echo true; or echo false)
check "clone: the cloned entry's provenance survived" true (grep -q clone-empty.git $cl_new/agent-vault/projects/$cl_empty_slug/origin; and echo true; or echo false)
check "clone: the live link points at the migrated entry" (path resolve $cl_new/agent-vault/projects/$cl_empty_slug/claude/memory) (path resolve $cl_croot2/$cl_mig_mangled/memory)

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

# The allowlist has to hold *inside* knowledge/ too, not only at the agy
# root. These are the same hostile shapes planted above, one level down --
# where a recursive copy of the directory took them verbatim into a commit
# while the documentation promised nothing new upstream added could leak.
mkdir -p $agy5/knowledge/notes $agy5/knowledge/.hidden
echo nested >$agy5/knowledge/notes/deep.md
echo '{"k":"v"}' >$agy5/knowledge/meta.json
echo SECRET-INSIDE-KNOWLEDGE >$agy5/knowledge/.credentials.json
echo SECRET-INSIDE-KNOWLEDGE >$agy5/knowledge/.hidden/leak.json
echo SECRET-INSIDE-KNOWLEDGE >$agy5/knowledge/history.jsonl
printf 'transcript\n' >$agy5/knowledge/session.jsonl
: >$agy5/knowledge/knowledge.lock
: >$agy5/knowledge/conversations.db
: >$agy5/knowledge/conversations.db-wal
: >$agy5/knowledge/conversations.db-shm

# Symlinks inside the store. The extension allowlist bounds what *kind* of
# file is collected; it says nothing about whose. A store-relative walk
# that dereferenced links would pull qualifying .md and .json out of
# whatever the link names -- a real home directory is full of them -- so
# the store boundary has to hold on its own. $outside5 stands in for that
# home: a directory the store has no business reaching into, planted with
# exactly the shapes that qualify.
set -l outside5 (mktemp -d); set -ga TMPDIRS $outside5
mkdir -p $outside5/nested
echo SECRET-OUTSIDE-KNOWLEDGE >$outside5/leaked.json
echo SECRET-OUTSIDE-KNOWLEDGE >$outside5/target.md
echo SECRET-OUTSIDE-KNOWLEDGE >$outside5/nested/deep.md
ln -s $outside5 $agy5/knowledge/linked
ln -s $outside5/target.md $agy5/knowledge/alias.md
# Not a cycle, so a recursive glob's cycle guard does not catch it: a link
# to the filesystem root simply makes the walk enormous. This one is here
# for the clock as much as for the contents -- the copy runs synchronously
# in front of every agent launch, and a `**` glob over this fixture did
# not return within 20s.
ln -s / $agy5/knowledge/root
# A genuine cycle too, since the walk must not depend on the glob's guard.
mkdir -p $agy5/knowledge/cyc
ln -s $agy5/knowledge $agy5/knowledge/cyc/loop

# A global (non-per-project) Claude memory directory with a sentinel file.
# __fish_agent_vault_claude_home is what keeps this off the real ~/.claude:
# if agents-vault ignored the override, these checks would fail here *and*
# the real global memory would be moved into $chome5.
mkdir -p $chome5/memory
echo global-memory >$chome5/memory/g.md

set -l gp (new_repo https://git.rootiest.dev/rootiest/globals.git)
set -l t5_start (date +%s)
pushd $gp >/dev/null
agents-vault --silent
popd >/dev/null
set -l t5_elapsed (math (date +%s) - $t5_start)

check "agy knowledge copied" learned (cat $vroot5/agent-vault/global/agy/knowledge/fact.md)
check "agy settings copied" '{"model":"x"}' (cat $vroot5/agent-vault/global/agy/settings.json)
check "agy knowledge is a copy not a link" false (test -L $vroot5/agent-vault/global/agy/knowledge; and echo true; or echo false)
check "history.jsonl not copied" false (test -e $vroot5/agent-vault/global/agy/history.jsonl; and echo true; or echo false)
check "conversations not copied" false (test -e $vroot5/agent-vault/global/agy/conversations; and echo true; or echo false)

# Inside knowledge/: the notes come through, everything else stays out.
check "knowledge: nested markdown copied" nested (cat $vroot5/agent-vault/global/agy/knowledge/notes/deep.md 2>/dev/null)
check "knowledge: json metadata copied" '{"k":"v"}' (cat $vroot5/agent-vault/global/agy/knowledge/meta.json 2>/dev/null)
for decoy in .credentials.json .hidden history.jsonl session.jsonl knowledge.lock conversations.db conversations.db-wal conversations.db-shm
    check "knowledge: $decoy stayed out" false (test -e $vroot5/agent-vault/global/agy/knowledge/$decoy; and echo true; or echo false)
end
# Not merely absent from the worktree: absent from the history, which is
# what actually leaves the machine on a push.
check "knowledge: no secret reached a commit" false (git -C $vroot5/agent-vault grep -q SECRET-INSIDE-KNOWLEDGE HEAD -- global 2>/dev/null; and echo true; or echo false)

# Symlinks: nothing the links name may appear, under any name. The linked
# directory must not exist in the vault at all (following it would recreate
# its tree wholesale), and the aliased file must not exist either, even
# though its own name qualifies -- a dereferencing copy writes a real file
# at the link's name and the extension rule waves it through.
for escapee in linked linked/leaked.json linked/nested/deep.md alias.md root cyc/loop
    check "knowledge: symlinked $escapee stayed out" false (test -e $vroot5/agent-vault/global/agy/knowledge/$escapee; and echo true; or echo false)
end
check "knowledge: nothing outside the store reached a commit" false (git -C $vroot5/agent-vault grep -q SECRET-OUTSIDE-KNOWLEDGE HEAD 2>/dev/null; and echo true; or echo false)
# The clock, not the contents: a walk that descends a link to / does not
# finish, and this is the every-launch path. Generous enough that a loaded
# machine cannot fail it by being slow.
check "knowledge: a link to / does not stall the launch path" true (test $t5_elapsed -lt 20; and echo true; or echo false)
# A torn database with its completing write-ahead log deliberately excluded
# is worse than no database at all, so the scaffold ignores all three.
check "scaffolded .gitignore excludes *.db" true (grep -qxF '*.db' $vroot5/agent-vault/.gitignore; and echo true; or echo false)
# Both stash fallbacks, or a crash mid-rename leaves a shadow copy of an
# entry sitting at the vault root for the next `git add -A` to commit.
check "scaffolded .gitignore excludes /.adopt-stash" true (grep -qxF '/.adopt-stash' $vroot5/agent-vault/.gitignore; and echo true; or echo false)
check "scaffolded .gitignore excludes /.migrate-stash" true (grep -qxF '/.migrate-stash' $vroot5/agent-vault/.gitignore; and echo true; or echo false)

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

#   ──────────────────── status / adopt / remote / push ───────────────────
# The four report-and-rebind modes. --status is a *report*: the checks
# below pin that it never mutates, because it is dispatched ahead of the
# scaffold rather than behind it.
echo ""
echo "== agents-vault (status, remote, adopt) =="

set -l vroot9 (mktemp -d); set -ga TMPDIRS $vroot9
set -l croot9 (mktemp -d); set -ga TMPDIRS $croot9
set -l chome9 (mktemp -d); set -ga TMPDIRS $chome9
set -l agy9 (mktemp -d); set -ga TMPDIRS $agy9
set -g __fish_agent_vault_dir $vroot9/agent-vault
set -g __fish_agent_vault_claude_root $croot9
set -g __fish_agent_vault_claude_home $chome9
set -g __fish_agent_vault_agy_root $agy9

# A report asked for before the vault exists must say so, not scaffold one.
set -l s0out (mktemp); set -ga TMPDIRS $s0out
set -l s0rc (agents-vault --status >$s0out; echo $status)
check "status without a vault exits 0" 0 "$s0rc"
check "status without a vault says so" true (string match -q '*no vault*' -- (cat $s0out); and echo true; or echo false)
check "status without a vault scaffolds nothing" false (test -e $vroot9/agent-vault; and echo true; or echo false)

set -l sp (new_repo https://git.rootiest.dev/rootiest/statusrepo.git)
set -l smangled (string replace -a '/' '-' -- $sp | string replace -a '.' '-')
mkdir -p $croot9/$smangled/memory
echo m >$croot9/$smangled/memory/m.md
pushd $sp >/dev/null
agents-vault --silent
set -l report (agents-vault --status)
popd >/dev/null

check "status names the slug" true (string match -q '*git.rootiest.dev-rootiest-statusrepo*' -- "$report"; and echo true; or echo false)
check "status reports no remote" true (string match -q '*no remote*' -- "$report"; and echo true; or echo false)
check "status reports the link as healthy" true (string match -q '*linked*' -- "$report"; and echo true; or echo false)

# --status must not mutate. Global state that a default run *would* sync is
# staged here and must still be untouched afterwards: a report that first
# copies the agy knowledge store and claims ~/.claude/memory is not a
# report. This is what dispatching --status ahead of the scaffold buys.
mkdir -p $agy9/knowledge
echo learned >$agy9/knowledge/fact.md
mkdir -p $chome9/memory
echo global >$chome9/memory/g.md
set -l head_before (git -C $vroot9/agent-vault rev-list --count HEAD)
set -l porcelain_before (git -C $vroot9/agent-vault status --porcelain | string join ',')
agents-vault --status >/dev/null
check "status did not copy agy state" false (test -e $vroot9/agent-vault/global/agy; and echo true; or echo false)
check "status did not claim the global memory path" false (test -L $chome9/memory; and echo true; or echo false)
check "status made no commit" "$head_before" (git -C $vroot9/agent-vault rev-list --count HEAD)
check "status left the vault worktree as it found it" "$porcelain_before" (git -C $vroot9/agent-vault status --porcelain | string join ',')

# An entry no live project links to is surfaced as an orphan.
mkdir -p $vroot9/agent-vault/projects/ghost-entry/claude/memory
echo x >$vroot9/agent-vault/projects/ghost-entry/claude/memory/x.md
set -l oreport (agents-vault --status)
check "status lists the orphan" true (string match -q '*orphan*ghost-entry*' -- "$oreport"; and echo true; or echo false)
rm -rf $vroot9/agent-vault/projects/ghost-entry

# --remote sets origin on the vault.
agents-vault --remote=https://git.rootiest.dev/rootiest/agent-vault.git --silent
check "remote set" https://git.rootiest.dev/rootiest/agent-vault.git (git -C $vroot9/agent-vault remote get-url origin)
check "status reports the remote" true (string match -q '*rootiest/agent-vault.git*' -- (agents-vault --status); and echo true; or echo false)

# A *failed* remote update must return non-zero. Reporting success after a
# git command that did not run is the same silent-false-success shape that
# a hook-rejected commit produced earlier in this project.
set -l rerr (mktemp); set -ga TMPDIRS $rerr
chmod 500 $vroot9/agent-vault/.git
set -l rrc (agents-vault --remote=https://git.rootiest.dev/rootiest/other.git --silent 2>$rerr; echo $status)
chmod 700 $vroot9/agent-vault/.git
check "failing --remote returns 1" 1 "$rrc"
check "failing --remote reports on stderr" true (string match -q '*could not set*remote*' -- (cat $rerr); and echo true; or echo false)
check "failing --remote left the old remote in place" https://git.rootiest.dev/rootiest/agent-vault.git (git -C $vroot9/agent-vault remote get-url origin)

# --adopt renames the current project's entry.
set -l ap (new_repo)
set -l amang (string replace -a '/' '-' -- $ap | string replace -a '.' '-')
mkdir -p $croot9/$amang/memory
echo adopted >$croot9/$amang/memory/a.md
pushd $ap >/dev/null
agents-vault --silent
set -l aslug (_agents_repo_slug $ap)
agents-vault --adopt=my-chosen-slug --silent
popd >/dev/null
check "adopt renamed the entry" adopted (cat $vroot9/agent-vault/projects/my-chosen-slug/claude/memory/a.md)
check "adopt repinned the link" (path resolve $vroot9/agent-vault/projects/my-chosen-slug/claude/memory) (path resolve $croot9/$amang/memory)
check "adopt removed the old entry" false (test -d $vroot9/agent-vault/projects/$aslug; and echo true; or echo false)
check "adopt recorded the rebind" true (string match -q "*$aslug*my-chosen-slug*" -- (cat $vroot9/agent-vault/projects/my-chosen-slug/origin); and echo true; or echo false)

# An unvalidated --adopt slug is a path-traversal primitive: it lands in
# "$vault/projects/$slug" and in `git mv`. Only the charset the slug
# formula itself emits is accepted, plus a by-name refusal of the two
# traversal names that need no slash.
set -l bp (new_repo)
set -l bmang (string replace -a '/' '-' -- $bp | string replace -a '.' '-')
mkdir -p $croot9/$bmang/memory
echo bad >$croot9/$bmang/memory/b.md
pushd $bp >/dev/null
agents-vault --silent
popd >/dev/null
set -l projects_before (command ls -A $vroot9/agent-vault/projects | sort | string join ',')

set -l bad_slugs ../escape has/slash . .. 'UPPER' 'sp ace' ''
pushd $bp >/dev/null
for bad in $bad_slugs
    set -l berr (mktemp); set -ga TMPDIRS $berr
    set -l brc (agents-vault --adopt=$bad --silent 2>$berr; echo $status)
    check "adopt refuses '$bad'" 1 "$brc"
    check "adopt refuses '$bad' out loud" true (string match -q '*invalid*' -- (cat $berr); and echo true; or echo false)
end
popd >/dev/null

check "refused adopts moved nothing" "$projects_before" (command ls -A $vroot9/agent-vault/projects | sort | string join ',')
check "refused adopts escaped nothing above projects/" false (test -e $vroot9/agent-vault/escape; and echo true; or echo false)

# ... but a *leading* dot is legitimate, not traversal. _agents_repo_slug
# emits one for a dot-led subdomain, so refusing it would make such an
# entry impossible to adopt. Inside projects/ it is a hidden directory.
pushd $bp >/dev/null
set -l drc (agents-vault --adopt=.hidden.example.com-repo --silent; echo $status)
popd >/dev/null
check "adopt accepts a leading-dot slug" 0 "$drc"
check "leading-dot slug landed inside projects/" bad (cat $vroot9/agent-vault/projects/.hidden.example.com-repo/claude/memory/b.md 2>/dev/null)
check "leading-dot slug escaped nothing" false (test -e $vroot9/agent-vault/.hidden.example.com-repo; and echo true; or echo false)
check "leading-dot slug repinned the link" (path resolve $vroot9/agent-vault/projects/.hidden.example.com-repo/claude/memory) (path resolve $croot9/$bmang/memory)

# --adopt must be atomic. A rename that lands while the relink fails
# leaves the memory intact but unreferenced: the next ordinary run finds
# no live link, recomputes the old slug, finds nothing there, and
# fabricates a fresh empty entry, so the agent writes history-less memory
# from then on. The relink is forced to fail by making the project's live
# parent directory read-only, which stops ensure_symlink repinning it.
set -l tp (new_repo https://git.rootiest.dev/rootiest/atomic.git)
set -l tslug git.rootiest.dev-rootiest-atomic
set -l tmang (string replace -a '/' '-' -- $tp | string replace -a '.' '-')
mkdir -p $croot9/$tmang/memory
echo atomic-precious >$croot9/$tmang/memory/keep.md
pushd $tp >/dev/null
agents-vault --silent
popd >/dev/null

set -l pre_entries (command ls -A $vroot9/agent-vault/projects | sort | string join ',')
set -l pre_head (git -C $vroot9/agent-vault rev-list --count HEAD)
set -l pre_porcelain (git -C $vroot9/agent-vault status --porcelain | string join ',')
set -l pre_link (path resolve $croot9/$tmang/memory)

set -l terr (mktemp); set -ga TMPDIRS $terr
chmod 500 $croot9/$tmang
pushd $tp >/dev/null
set -l trc (agents-vault --adopt=atomic-target --silent 2>$terr; echo $status)
popd >/dev/null
chmod 700 $croot9/$tmang

check "atomic adopt: failed relink returns 1" 1 "$trc"
check "atomic adopt: says the entry was left alone" true (string match -q "*$tslug*left as it was*" -- (cat $terr); and echo true; or echo false)
check "atomic adopt: rename rolled back" "$pre_entries" (command ls -A $vroot9/agent-vault/projects | sort | string join ',')
check "atomic adopt: target entry not created" false (test -e $vroot9/agent-vault/projects/atomic-target; and echo true; or echo false)
check "atomic adopt: original entry intact" atomic-precious (cat $vroot9/agent-vault/projects/$tslug/claude/memory/keep.md 2>/dev/null)
check "atomic adopt: no origin note appended" false (string match -q '*adopted:*' -- (cat $vroot9/agent-vault/projects/$tslug/origin); and echo true; or echo false)
check "atomic adopt: nothing committed" "$pre_head" (git -C $vroot9/agent-vault rev-list --count HEAD)
check "atomic adopt: index and worktree unchanged" "$pre_porcelain" (git -C $vroot9/agent-vault status --porcelain | string join ',')
check "atomic adopt: live link never removed" "$pre_link" (path resolve $croot9/$tmang/memory)
check "atomic adopt: no stash left behind" false (test -e $vroot9/agent-vault/.adopt-stash; and echo true; or echo false)

# The point of rolling back: an ordinary run afterwards must find the
# original entry and must NOT fabricate a second one.
pushd $tp >/dev/null
agents-vault --silent
popd >/dev/null
check "atomic adopt: ordinary run fabricated no entry" "$pre_entries" (command ls -A $vroot9/agent-vault/projects | sort | string join ',')
check "atomic adopt: ordinary run kept the original link" (path resolve $vroot9/agent-vault/projects/$tslug/claude/memory) (path resolve $croot9/$tmang/memory)
check "atomic adopt: memory still reachable through the link" atomic-precious (cat $croot9/$tmang/memory/keep.md 2>/dev/null)

# ... and once the underlying problem is fixed, --adopt simply works.
pushd $tp >/dev/null
set -l t2rc (agents-vault --adopt=atomic-target --silent; echo $status)
popd >/dev/null
check "atomic adopt: retry succeeds" 0 "$t2rc"
check "atomic adopt: retry moved the memory" atomic-precious (cat $vroot9/agent-vault/projects/atomic-target/claude/memory/keep.md 2>/dev/null)

# The cases above all adopt onto a slug with no entry at all. The other
# half of --adopt is a target that already exists but holds no memory -- a
# scaffolded entry, or one a departed project left behind. That one is
# stashed rather than deleted, so a failed relink can put it back exactly
# as it was.
set -l sa (new_repo https://git.rootiest.dev/rootiest/stash-src.git)
set -l saslug git.rootiest.dev-rootiest-stash-src
set -l samang (string replace -a '/' '-' -- $sa | string replace -a '.' '-')
mkdir -p $croot9/$samang/memory
echo stash-precious >$croot9/$samang/memory/keep.md
pushd $sa >/dev/null
agents-vault --silent
popd >/dev/null

# The target must be *tracked* for this to bite: stashing it takes files
# git knows about out from under the index, which is the whole hazard.
mkdir -p $vroot9/agent-vault/projects/stash-target/claude/memory
printf 'remote: (none)\npath:   %s\nhost:   t\n' /nowhere \
    >$vroot9/agent-vault/projects/stash-target/origin
pushd $sa >/dev/null
agents-vault --silent
popd >/dev/null
check "stash adopt: target entry is tracked" true (git -C $vroot9/agent-vault ls-files --error-unmatch projects/stash-target/origin >/dev/null 2>&1; and echo true; or echo false)
check "stash adopt: vault clean before the adopt" "" (git -C $vroot9/agent-vault status --porcelain | string join ',')

# Where the stash lives is load-bearing rather than cosmetic: at the vault
# root, a crash between the two moves leaves it for the next ordinary run's
# `git add -A` to commit as permanent junk. Inside .git/ it is out of reach
# of both the entry walk and `git add -A`. Pinned by making the vault root
# itself unwritable for the duration -- adopt writes nothing there, so only
# a stash at the root would need it.
chmod 500 $vroot9/agent-vault
pushd $sa >/dev/null
set -l sarc (agents-vault --adopt=stash-target --silent; echo $status)
popd >/dev/null
chmod 700 $vroot9/agent-vault
check "stash adopt: succeeds over a contentless target" 0 "$sarc"
check "stash adopt: memory moved to the target slug" stash-precious (cat $vroot9/agent-vault/projects/stash-target/claude/memory/keep.md 2>/dev/null)
check "stash adopt: source entry removed" false (test -d $vroot9/agent-vault/projects/$saslug; and echo true; or echo false)
check "stash adopt: link repinned onto the target" (path resolve $vroot9/agent-vault/projects/stash-target/claude/memory) (path resolve $croot9/$samang/memory)
check "stash adopt: stash cleaned up" false (test -e $vroot9/agent-vault/.git/agents-vault-adopt-stash; and echo true; or echo false)
check "stash adopt: nothing stashed at the vault root" false (test -e $vroot9/agent-vault/.adopt-stash; and echo true; or echo false)
check "stash adopt: the root fallback location is gitignored" true (git -C $vroot9/agent-vault check-ignore -q .adopt-stash; and echo true; or echo false)
check "stash adopt: vault clean afterwards" "" (git -C $vroot9/agent-vault status --porcelain | string join ',')

# ... and when the relink fails, the stash must come back and the *index*
# must come back with it. Restoring the worktree alone leaves git
# describing a half-applied rename -- the files are right, git status is
# not -- and a hand commit in that window records it.
set -l sf (new_repo https://git.rootiest.dev/rootiest/stash-fail.git)
set -l sfslug git.rootiest.dev-rootiest-stash-fail
set -l sfmang (string replace -a '/' '-' -- $sf | string replace -a '.' '-')
mkdir -p $croot9/$sfmang/memory
echo stashfail-precious >$croot9/$sfmang/memory/keep.md
pushd $sf >/dev/null
agents-vault --silent
popd >/dev/null

mkdir -p $vroot9/agent-vault/projects/stashfail-target/claude/memory
printf 'remote: (none)\npath:   %s\nhost:   t\n' /nowhere-else \
    >$vroot9/agent-vault/projects/stashfail-target/origin
pushd $sf >/dev/null
agents-vault --silent
popd >/dev/null

set -l sf_entries (command ls -A $vroot9/agent-vault/projects | sort | string join ',')
set -l sf_head (git -C $vroot9/agent-vault rev-list --count HEAD)
set -l sf_porcelain (git -C $vroot9/agent-vault status --porcelain | string join ',')
set -l sf_link (path resolve $croot9/$sfmang/memory)
check "stash adopt rollback: vault clean before the adopt" "" "$sf_porcelain"

set -l sferr (mktemp); set -ga TMPDIRS $sferr
chmod 500 $croot9/$sfmang
pushd $sf >/dev/null
set -l sfrc (agents-vault --adopt=stashfail-target --silent 2>$sferr; echo $status)
popd >/dev/null
chmod 700 $croot9/$sfmang

check "stash adopt rollback: failed relink returns 1" 1 "$sfrc"
check "stash adopt rollback: says the entry was left alone" true (string match -q "*$sfslug*left as it was*" -- (cat $sferr); and echo true; or echo false)
check "stash adopt rollback: entries unchanged" "$sf_entries" (command ls -A $vroot9/agent-vault/projects | sort | string join ',')
check "stash adopt rollback: source entry intact" stashfail-precious (cat $vroot9/agent-vault/projects/$sfslug/claude/memory/keep.md 2>/dev/null)
check "stash adopt rollback: stashed target came back" true (string match -q '*nowhere-else*' -- (cat $vroot9/agent-vault/projects/stashfail-target/origin 2>/dev/null); and echo true; or echo false)
check "stash adopt rollback: target memory still contentless" 0 (command ls -A $vroot9/agent-vault/projects/stashfail-target/claude/memory 2>/dev/null | count)
check "stash adopt rollback: nothing committed" "$sf_head" (git -C $vroot9/agent-vault rev-list --count HEAD)
check "stash adopt rollback: index and worktree unchanged" "$sf_porcelain" (git -C $vroot9/agent-vault status --porcelain | string join ',')
check "stash adopt rollback: no stash left behind" false (test -e $vroot9/agent-vault/.git/agents-vault-adopt-stash -o -e $vroot9/agent-vault/.adopt-stash; and echo true; or echo false)
check "stash adopt rollback: live link never removed" "$sf_link" (path resolve $croot9/$sfmang/memory)
check "stash adopt rollback: memory still reachable live" stashfail-precious (cat $croot9/$sfmang/memory/keep.md 2>/dev/null)

# The point of rolling back: the ordinary run afterwards finds the original
# entry instead of fabricating a fresh, history-less one.
pushd $sf >/dev/null
agents-vault --silent
popd >/dev/null
check "stash adopt rollback: ordinary run fabricated no entry" "$sf_entries" (command ls -A $vroot9/agent-vault/projects | sort | string join ',')
check "stash adopt rollback: ordinary run kept the memory reachable" stashfail-precious (cat $croot9/$sfmang/memory/keep.md 2>/dev/null)

# The other rollback in --adopt: the *forward* move failing outright,
# before the relink is ever reached. A plain file sitting where the target
# entry would go makes `git mv` refuse ("destination already exists") and
# the coreutils fallback refuse too ("cannot overwrite non-directory"), so
# the worktree needs no repair -- but the index does, and that is the half
# of the rollback nothing else pins. With a real git there is no way for a
# test to leave a genuinely half-applied rename here, so the divergence
# stands in for one: the index is desynced by hand first, and the check
# that matters is that the way out re-read projects/ and healed it.
# Without that setup the repair is an invisible no-op, and a refactor can
# drop it with the suite still green.
set -l ff (new_repo https://git.rootiest.dev/rootiest/fwd-fail.git)
set -l ffslug git.rootiest.dev-rootiest-fwd-fail
set -l ffmang (string replace -a '/' '-' -- $ff | string replace -a '.' '-')
mkdir -p $croot9/$ffmang/memory
echo fwdfail-precious >$croot9/$ffmang/memory/keep.md
pushd $ff >/dev/null
agents-vault --silent
popd >/dev/null

# The blocker must be tracked and committed, so that the only thing dirty
# at adopt time is the divergence staged just below.
echo occupied >$vroot9/agent-vault/projects/fwdfail-target
pushd $ff >/dev/null
agents-vault --silent
popd >/dev/null
check "fwd-fail adopt: the blocking file is tracked" true (git -C $vroot9/agent-vault ls-files --error-unmatch projects/fwdfail-target >/dev/null 2>&1; and echo true; or echo false)
check "fwd-fail adopt: vault clean before the divergence" "" (git -C $vroot9/agent-vault status --porcelain | string join ',')

git -C $vroot9/agent-vault rm -q --cached projects/$ffslug/origin >/dev/null
set -l ff_dirty (git -C $vroot9/agent-vault status --porcelain | string join ',')
check "fwd-fail adopt: index diverges before the adopt" true (string match -q "*D  projects/$ffslug/origin*" -- "$ff_dirty"; and echo true; or echo false)

set -l ff_entries (command ls -A $vroot9/agent-vault/projects | sort | string join ',')
set -l ff_head (git -C $vroot9/agent-vault rev-list --count HEAD)
set -l ff_link (path resolve $croot9/$ffmang/memory)

pushd $ff >/dev/null
set -l ffrc (agents-vault --adopt=fwdfail-target --silent 2>/dev/null; echo $status)
popd >/dev/null

check "fwd-fail adopt: returns 1" 1 "$ffrc"
check "fwd-fail adopt: entries unchanged" "$ff_entries" (command ls -A $vroot9/agent-vault/projects | sort | string join ',')
check "fwd-fail adopt: source entry intact" fwdfail-precious (cat $vroot9/agent-vault/projects/$ffslug/claude/memory/keep.md 2>/dev/null)
check "fwd-fail adopt: blocking file untouched" occupied (cat $vroot9/agent-vault/projects/fwdfail-target 2>/dev/null)
check "fwd-fail adopt: no origin note appended" false (string match -q '*adopted:*' -- (cat $vroot9/agent-vault/projects/$ffslug/origin); and echo true; or echo false)
check "fwd-fail adopt: nothing committed" "$ff_head" (git -C $vroot9/agent-vault rev-list --count HEAD)
check "fwd-fail adopt: live link never removed" "$ff_link" (path resolve $croot9/$ffmang/memory)
check "fwd-fail adopt: memory still reachable live" fwdfail-precious (cat $croot9/$ffmang/memory/keep.md 2>/dev/null)
check "fwd-fail adopt: no stash left behind" false (test -e $vroot9/agent-vault/.git/agents-vault-adopt-stash -o -e $vroot9/agent-vault/.adopt-stash; and echo true; or echo false)
# The pin: projects/ was re-read on the way out, so git describes the
# files as they actually are rather than as the abandoned rename left them.
check "fwd-fail adopt: index re-read to match the worktree" "" (git -C $vroot9/agent-vault status --porcelain | string join ',')
check "fwd-fail adopt: nothing left staged against HEAD" "" (git -C $vroot9/agent-vault diff HEAD --name-only | string join ',')

# And the ordinary run afterwards still finds the original entry.
pushd $ff >/dev/null
agents-vault --silent
popd >/dev/null
check "fwd-fail adopt: ordinary run fabricated no entry" "$ff_entries" (command ls -A $vroot9/agent-vault/projects | sort | string join ',')
check "fwd-fail adopt: ordinary run kept the memory reachable" fwdfail-precious (cat $croot9/$ffmang/memory/keep.md 2>/dev/null)

set -e __fish_agent_vault_dir
set -e __fish_agent_vault_claude_root
set -g __fish_agent_vault_claude_home $HERMETIC_HOME/claude
set -g __fish_agent_vault_agy_root $HERMETIC_HOME/agy

#   ─────────────────────────────── restore ───────────────────────────────
# The batch counterpart of the emergent per-project restore: walk the vault
# and relink every entry whose recorded origin path still exists.
echo ""
echo "== agents-vault (restore) =="

set -l vroot10 (mktemp -d); set -ga TMPDIRS $vroot10
set -l croot10 (mktemp -d); set -ga TMPDIRS $croot10
set -l chome10 (mktemp -d); set -ga TMPDIRS $chome10
set -l agy10 (mktemp -d); set -ga TMPDIRS $agy10
set -g __fish_agent_vault_dir $vroot10/agent-vault
set -g __fish_agent_vault_claude_root $croot10
set -g __fish_agent_vault_claude_home $chome10
set -g __fish_agent_vault_agy_root $agy10

set -l rp (new_repo https://git.rootiest.dev/rootiest/restoreme.git)
set -l rmang (string replace -a '/' '-' -- $rp | string replace -a '.' '-')
mkdir -p $croot10/$rmang/memory
echo restore-precious >$croot10/$rmang/memory/keep.md
pushd $rp >/dev/null
agents-vault --silent
popd >/dev/null

# Lose the live link the way a reinstalled machine would.
rm -f $croot10/$rmang/memory
check "restore: link gone to begin with" false (test -e $croot10/$rmang/memory; and echo true; or echo false)

set -l rout (agents-vault --restore)
check "restore: relinked from the origin file" restore-precious (cat $croot10/$rmang/memory/keep.md 2>/dev/null)
check "restore: the live path is a link" true (test -L $croot10/$rmang/memory; and echo true; or echo false)
check "restore: names what it restored" true (string match -q '*restoreme*' -- "$rout"; and echo true; or echo false)

# An entry whose recorded path is gone cannot be placed; the run still
# succeeds and says which entry needs --adopt.
mkdir -p $vroot10/agent-vault/projects/ghost-entry/claude/memory
echo x >$vroot10/agent-vault/projects/ghost-entry/claude/memory/x.md
printf 'remote: (none)\npath:   %s\nhost:   t\n' $vroot10/gone-forever \
    >$vroot10/agent-vault/projects/ghost-entry/origin
set -l r2out (mktemp); set -ga TMPDIRS $r2out
set -l r2rc (agents-vault --restore >$r2out; echo $status)
check "restore: exits 0 with an unplaceable entry" 0 "$r2rc"
check "restore: reports the unplaceable entry" true (string match -q '*ghost-entry*' -- (cat $r2out); and echo true; or echo false)

# A dot-led slug is a real key, not a curiosity: the sibling-bare-mirror
# idiom (`git remote add origin ../mirror.git`) keys as ..-mirror, a
# dot-led host keys as .hidden.example.com-o-r, and --adopt accepts a
# leading dot on purpose. Fish's * skips such a name, so both walks list
# instead of globbing -- otherwise --status under-reports the entry and
# --restore leaves that project unlinked, both without saying a word.
set -l dotp (new_repo https://git.rootiest.dev/rootiest/dotted.git)
set -l dotmang (string replace -a '/' '-' -- $dotp | string replace -a '.' '-')
mkdir -p $vroot10/agent-vault/projects/.dot-entry/claude/memory
echo dot-precious >$vroot10/agent-vault/projects/.dot-entry/claude/memory/keep.md
printf 'remote: (none)\npath:   %s\nhost:   t\n' $dotp \
    >$vroot10/agent-vault/projects/.dot-entry/origin
check "dot-led entry: a glob really does skip it" false (string match -q '*.dot-entry*' -- (echo $vroot10/agent-vault/projects/*); and echo true; or echo false)

set -l dotreport (agents-vault --status)
check "status lists a dot-led entry" true (string match -q '*.dot-entry*' -- "$dotreport"; and echo true; or echo false)

set -l dotout (agents-vault --restore)
check "restore: relinks a dot-led entry" dot-precious (cat $croot10/$dotmang/memory/keep.md 2>/dev/null)
check "restore: the dot-led live path is a link" true (test -L $croot10/$dotmang/memory; and echo true; or echo false)
check "restore: names the dot-led entry it restored" true (string match -q '*.dot-entry*' -- "$dotout"; and echo true; or echo false)

# An entry that *could* be placed but could not be relinked is a failure,
# not a note in passing -- the same branchless-`if` false zero as the
# commit and push paths. An entry with no live project is not a failure.
rm -f $croot10/$rmang/memory
chmod 500 $croot10/$rmang
set -l r3err (mktemp); set -ga TMPDIRS $r3err
set -l r3rc (agents-vault --restore >/dev/null 2>$r3err; echo $status)
chmod 700 $croot10/$rmang
check "restore: a failed relink returns non-zero" 1 "$r3rc"
check "restore: a failed relink is reported" true (string match -q '*restoreme*' -- (cat $r3err); and echo true; or echo false)

set -e __fish_agent_vault_dir
set -e __fish_agent_vault_claude_root
set -g __fish_agent_vault_claude_home $HERMETIC_HOME/claude
set -g __fish_agent_vault_agy_root $HERMETIC_HOME/agy

#   ──────────────────────────────── push ─────────────────────────────────
echo ""
echo "== agents-vault (push) =="

set -l vroot11 (mktemp -d); set -ga TMPDIRS $vroot11
set -l croot11 (mktemp -d); set -ga TMPDIRS $croot11
set -l chome11 (mktemp -d); set -ga TMPDIRS $chome11
set -l agy11 (mktemp -d); set -ga TMPDIRS $agy11
set -l bare (mktemp -d); set -ga TMPDIRS $bare
git init -q --bare $bare
set -g __fish_agent_vault_dir $vroot11/agent-vault
set -g __fish_agent_vault_claude_root $croot11
set -g __fish_agent_vault_claude_home $chome11
set -g __fish_agent_vault_agy_root $agy11

set -l pp (new_repo https://git.rootiest.dev/rootiest/pushme.git)
set -l pslug git.rootiest.dev-rootiest-pushme
set -l pmang (string replace -a '/' '-' -- $pp | string replace -a '.' '-')
mkdir -p $croot11/$pmang/memory
echo pushed >$croot11/$pmang/memory/p.md

# --push with no remote must fail loudly. The commit still happened, so
# silently returning 0 would read as "backed up off this machine".
set -l perr (mktemp); set -ga TMPDIRS $perr
pushd $pp >/dev/null
set -l prc0 (agents-vault --push --silent 2>$perr; echo $status)
popd >/dev/null
check "push without a remote returns 1" 1 "$prc0"
check "push without a remote says so" true (string match -q '*no remote*' -- (cat $perr); and echo true; or echo false)
check "push without a remote still committed locally" true (git -C $vroot11/agent-vault ls-files --error-unmatch projects/$pslug/claude/memory/p.md >/dev/null 2>&1; and echo true; or echo false)

agents-vault --remote=$bare --silent
set -l vbranch (git -C $vroot11/agent-vault rev-parse --abbrev-ref HEAD)
pushd $pp >/dev/null
set -l prc (agents-vault --push --silent; echo $status)
popd >/dev/null
check "push exits 0" 0 "$prc"
check "push landed in the remote" pushed (git -C $bare show $vbranch:projects/$pslug/claude/memory/p.md 2>/dev/null)

# Autopush is opt-in and off by default: a plain run must not push.
echo pushed-later >$croot11/$pmang/memory/p2.md
pushd $pp >/dev/null
agents-vault --silent
popd >/dev/null
check "no autopush by default" false (git -C $bare cat-file -e $vbranch:projects/$pslug/claude/memory/p2.md 2>/dev/null; and echo true; or echo false)

set -g __fish_agent_vault_autopush 1
echo pushed-auto >$croot11/$pmang/memory/p3.md
pushd $pp >/dev/null
agents-vault --silent
popd >/dev/null
set -e __fish_agent_vault_autopush
check "autopush pushes when enabled" pushed-auto (git -C $bare show $vbranch:projects/$pslug/claude/memory/p3.md 2>/dev/null)

# A push that *fails* against a configured remote must return non-zero.
# The function otherwise ends on a branchless `if`, which resolves to 0,
# so warning on stderr and falling through reports a successful backup
# while nothing left the machine -- the exact loss the vault prevents.
# The remote is a real path that is not a repository, not a mock.
set -l deadremote $vroot11/not-a-repo.git
agents-vault --remote=$deadremote --silent
echo pushed-never >$croot11/$pmang/memory/p4.md
set -l fperr (mktemp); set -ga TMPDIRS $fperr
pushd $pp >/dev/null
set -l fprc (agents-vault --push --silent 2>$fperr; echo $status)
popd >/dev/null
check "failing push returns non-zero" 1 "$fprc"
check "failing push warns on stderr" true (string match -q '*push failed*' -- (cat $fperr); and echo true; or echo false)
check "failing push still committed locally" true (git -C $vroot11/agent-vault ls-files --error-unmatch projects/$pslug/claude/memory/p4.md >/dev/null 2>&1; and echo true; or echo false)

# Autopush is the same failure through the quiet path: a summary line
# saying "Synced" must not come with a zero exit when the push failed.
echo pushed-never-2 >$croot11/$pmang/memory/p5.md
set -g __fish_agent_vault_autopush 1
set -l fp2err (mktemp); set -ga TMPDIRS $fp2err
pushd $pp >/dev/null
set -l fp2rc (agents-vault --quiet 2>$fp2err >/dev/null; echo $status)
popd >/dev/null
set -e __fish_agent_vault_autopush
check "failing autopush returns non-zero" 1 "$fp2rc"

# Autopush runs synchronously in front of every agent launch, so it must be
# bounded. Nothing in git bounds it: there is no HTTP connect timeout in
# its configuration, http.lowSpeedLimit/http.lowSpeedTime only start
# counting once bytes move, and GIT_TERMINAL_PROMPT/GIT_ASKPASS close the
# credential prompt rather than the socket. Unwrapped, this remote took
# 135s to give up. 192.0.2.1 is TEST-NET-1: reserved, unrouted, and
# therefore a blackhole rather than a fast refusal. A network that does
# refuse it quickly makes this pass without proving much, which is the
# right way round for a test that must never fail spuriously.
#
# This test costs its own bound in wall time. That is the price of
# measuring a timeout, and this defect -- a network call on the launch
# path -- has now been introduced twice.
set -l blackhole https://192.0.2.1/vault.git
agents-vault --remote=$blackhole --silent
echo pushed-into-the-void >$croot11/$pmang/memory/p6.md
set -g __fish_agent_vault_autopush 1
set -l bh_start (date +%s)
pushd $pp >/dev/null
set -l bhrc (agents-vault --silent 2>/dev/null; echo $status)
popd >/dev/null
set -l bh_elapsed (math (date +%s) - $bh_start)
set -e __fish_agent_vault_autopush
check "autopush to a blackholed remote returns non-zero" 1 "$bhrc"
check "autopush to a blackholed remote is bounded" true (test $bh_elapsed -lt 60; and echo true; or echo false)
check "a bounded autopush still committed locally" true (git -C $vroot11/agent-vault ls-files --error-unmatch projects/$pslug/claude/memory/p6.md >/dev/null 2>&1; and echo true; or echo false)

set -e __fish_agent_vault_dir
set -e __fish_agent_vault_claude_root
set -g __fish_agent_vault_claude_home $HERMETIC_HOME/claude
set -g __fish_agent_vault_agy_root $HERMETIC_HOME/agy

#   ────────────── a failed vault commit is fatal, not a note ─────────────
# _agents_repo_sync's own rejection path is covered further up, but
# agents-vault has to *propagate* it. The function otherwise ends on a
# branchless `if`, which fish resolves to 0, and a backup tool that reports
# success while nothing was recorded recreates the exact loss the vault
# exists to prevent. That false zero has already bitten this project three
# times, so both ways a sync can fail are pinned here rather than one.
echo ""
echo "== agents-vault (a failed vault commit is fatal) =="

set -l vroot13 (mktemp -d); set -ga TMPDIRS $vroot13
set -l croot13 (mktemp -d); set -ga TMPDIRS $croot13
set -l chome13 (mktemp -d); set -ga TMPDIRS $chome13
set -l agy13 (mktemp -d); set -ga TMPDIRS $agy13
set -g __fish_agent_vault_dir $vroot13/agent-vault
set -g __fish_agent_vault_claude_root $croot13
set -g __fish_agent_vault_claude_home $chome13
set -g __fish_agent_vault_agy_root $agy13

set -l hp13 (new_repo https://git.rootiest.dev/rootiest/hookfail.git)
set -l hmang13 (string replace -a '/' '-' -- $hp13 | string replace -a '.' '-')
mkdir -p $croot13/$hmang13/memory
echo hook-precious >$croot13/$hmang13/memory/keep.md
pushd $hp13 >/dev/null
agents-vault --silent
popd >/dev/null

# The vault runs its own hooks out of .agents-tools/hooks -- agents-vault
# points core.hooksPath there itself -- so a rejecting pre-commit in that
# directory is exactly the shape of a real secret scanner blocking the
# vault commit. _agents_repo_install_tools only refreshes the shims when
# the version marker moves, so the replacement survives the run under test.
printf '#!/bin/sh\nexit 1\n' >$vroot13/agent-vault/.agents-tools/hooks/pre-commit
chmod +x $vroot13/agent-vault/.agents-tools/hooks/pre-commit
echo hook-more >$croot13/$hmang13/memory/keep2.md
set -l hhead13 (git -C $vroot13/agent-vault rev-list --count HEAD)
set -l herr13 (mktemp); set -ga TMPDIRS $herr13
pushd $hp13 >/dev/null
set -l hrc13 (agents-vault --silent 2>$herr13; echo $status)
popd >/dev/null
check "rejected vault commit returns non-zero" 1 "$hrc13"
check "rejected vault commit says nothing was recorded" true (string match -q '*nothing recorded*' -- (cat $herr13); and echo true; or echo false)
check "rejected vault commit really recorded nothing" "$hhead13" (git -C $vroot13/agent-vault rev-list --count HEAD)

set -e __fish_agent_vault_dir
set -e __fish_agent_vault_claude_root
set -g __fish_agent_vault_claude_home $HERMETIC_HOME/claude
set -g __fish_agent_vault_agy_root $HERMETIC_HOME/agy

# The other way a backup fails is a diverged remote -- but that is a
# push-time problem, not a launch-time one. The ordinary run must commit
# regardless, because a backup that stops working the moment the remote
# moves ahead (or goes out of reach) is not a backup; --push is where the
# divergence has to be reckoned with, and where the two ways it can fail
# have to be told apart.
set -l vroot14 (mktemp -d); set -ga TMPDIRS $vroot14
set -l croot14 (mktemp -d); set -ga TMPDIRS $croot14
set -l chome14 (mktemp -d); set -ga TMPDIRS $chome14
set -l agy14 (mktemp -d); set -ga TMPDIRS $agy14
set -g __fish_agent_vault_dir $vroot14/agent-vault
set -g __fish_agent_vault_claude_root $croot14
set -g __fish_agent_vault_claude_home $chome14
set -g __fish_agent_vault_agy_root $agy14

set -l bare14 (mktemp -d); set -ga TMPDIRS $bare14
git init -q --bare $bare14

set -l cp14 (new_repo https://git.rootiest.dev/rootiest/conflict.git)
set -l cslug14 git.rootiest.dev-rootiest-conflict
set -l cmang14 (string replace -a '/' '-' -- $cp14 | string replace -a '.' '-')
mkdir -p $croot14/$cmang14/memory
echo base >$croot14/$cmang14/memory/keep.md
pushd $cp14 >/dev/null
agents-vault --silent
popd >/dev/null
agents-vault --remote=$bare14 --silent
git -C $vroot14/agent-vault push -q -u origin HEAD:refs/heads/main

# Another machine records a conflicting change to the same line...
set -l cclone14 (mktemp -d); set -ga TMPDIRS $cclone14
git clone -q $bare14 $cclone14
git -C $cclone14 config user.email t@t
git -C $cclone14 config user.name t
git -C $cclone14 config commit.gpgsign false
git -C $cclone14 config core.hooksPath /dev/null
echo theirs >$cclone14/projects/$cslug14/claude/memory/keep.md
git -C $cclone14 commit -qam theirs
git -C $cclone14 push -q origin HEAD:main

# ... while this one writes conflicting memory of its own on the same
# line. The ordinary run has to commit it: it never fetches, so the
# divergence is invisible to it and irrelevant.
set -l cerr14 (mktemp); set -ga TMPDIRS $cerr14
echo ours >$croot14/$cmang14/memory/keep.md
set -l chead14 (git -C $vroot14/agent-vault rev-list --count HEAD)
pushd $cp14 >/dev/null
set -l crc14 (agents-vault --silent 2>$cerr14; echo $status)
popd >/dev/null
check "diverged vault: ordinary run returns 0" 0 "$crc14"
check "diverged vault: ordinary run said nothing" "" (cat $cerr14)
check "diverged vault: ordinary run committed" (math $chead14 + 1) (git -C $vroot14/agent-vault rev-list --count HEAD)

# --push is where it is reckoned with: the pre-push pull replays that
# commit onto theirs, conflicts, aborts back to local HEAD, and reports a
# conflict. Nothing is pushed and the local memory survives untouched.
pushd $cp14 >/dev/null
set -l prc14 (agents-vault --push --silent 2>$cerr14; echo $status)
popd >/dev/null
check "vault push rebase conflict returns non-zero" 1 "$prc14"
check "vault push rebase conflict is named as one" true (string match -q '*rebase conflict*' -- (cat $cerr14); and echo true; or echo false)
check "vault push rebase conflict left no rebase in progress" false (test -d $vroot14/agent-vault/.git/rebase-merge -o -d $vroot14/agent-vault/.git/rebase-apply; and echo true; or echo false)
check "vault push rebase conflict kept the local memory" ours (cat $croot14/$cmang14/memory/keep.md)

# The other push-time failure is the remote being unreachable, and it must
# not be reported as the one above: no rebase ever starts, so calling it a
# rebase conflict sends the user hunting for a conflict that does not
# exist. (The old code said exactly that.) A bogus local path stands in
# for an unroutable host so the check costs nothing; the branch under test
# is the same one.
git -C $vroot14/agent-vault remote set-url origin /nonexistent/unreachable.git
echo more >$croot14/$cmang14/memory/keep2.md
set -l uhead14 (git -C $vroot14/agent-vault rev-list --count HEAD)
pushd $cp14 >/dev/null
set -l urc14 (agents-vault --push --silent 2>$cerr14; echo $status)
popd >/dev/null
check "unreachable remote: push returns non-zero" 1 "$urc14"
check "unreachable remote: not called a rebase conflict" false (string match -q '*rebase conflict*' -- (cat $cerr14); and echo true; or echo false)
check "unreachable remote: says it could not be reached" true (string match -q '*could not reach*' -- (cat $cerr14); and echo true; or echo false)
check "unreachable remote: the memory was still committed" (math $uhead14 + 1) (git -C $vroot14/agent-vault rev-list --count HEAD)
check "unreachable remote: left no rebase in progress" false (test -d $vroot14/agent-vault/.git/rebase-merge -o -d $vroot14/agent-vault/.git/rebase-apply; and echo true; or echo false)

# And the launch path itself -- the ordinary run both wrappers make -- is
# entirely unaffected by the unreachable remote. This is the regression
# that mattered most: with the pull on the commit path, a laptop off the
# network stopped being backed up at all while reporting nothing wrong.
echo offline-precious >$croot14/$cmang14/memory/keep3.md
set -l ohead14 (git -C $vroot14/agent-vault rev-list --count HEAD)
pushd $cp14 >/dev/null
set -l orc14 (agents-vault --silent 2>$cerr14; echo $status)
popd >/dev/null
check "offline launch run returns 0" 0 "$orc14"
check "offline launch run stayed silent" "" (cat $cerr14)
check "offline launch run committed the memory" (math $ohead14 + 1) (git -C $vroot14/agent-vault rev-list --count HEAD)
check "offline launch run really recorded it" offline-precious (git -C $vroot14/agent-vault show HEAD:projects/$cslug14/claude/memory/keep3.md 2>/dev/null)

set -e __fish_agent_vault_dir
set -e __fish_agent_vault_claude_root
set -g __fish_agent_vault_claude_home $HERMETIC_HOME/claude
set -g __fish_agent_vault_agy_root $HERMETIC_HOME/agy

#   ────────────── a dangling global memory link is repinned ──────────────
# The one state from the real incident the suite never pinned down. For a
# *broken* symlink both -d and -e are false, so only the `-L` disjunct in
# the global-memory guard can notice it; the vault side is deliberately
# left empty so no other disjunct can stand in and pass this by accident.
echo ""
echo "== agents-vault (dangling global memory link) =="

set -l vroot12 (mktemp -d); set -ga TMPDIRS $vroot12
set -l croot12 (mktemp -d); set -ga TMPDIRS $croot12
set -l chome12 (mktemp -d); set -ga TMPDIRS $chome12
set -l agy12 (mktemp -d); set -ga TMPDIRS $agy12
set -g __fish_agent_vault_dir $vroot12/agent-vault
set -g __fish_agent_vault_claude_root $croot12
set -g __fish_agent_vault_claude_home $chome12
set -g __fish_agent_vault_agy_root $agy12

ln -s $vroot12/vanished-vault/global/claude/memory $chome12/memory
check "dangling: -e is false for the broken link" false (test -e $chome12/memory; and echo true; or echo false)
check "dangling: -L is the only signal" true (test -L $chome12/memory; and echo true; or echo false)
check "dangling: the vault side is empty" false (test -e $vroot12/agent-vault/global/claude/memory; and echo true; or echo false)

set -l dp (new_repo https://git.rootiest.dev/rootiest/dangling.git)
set -l derr (mktemp); set -ga TMPDIRS $derr
pushd $dp >/dev/null
set -l drc (agents-vault --silent 2>$derr; echo $status)
popd >/dev/null

check "dangling: exits 0" 0 "$drc"
check "dangling: warns about nothing" "" (cat $derr)
check "dangling: repinned into the vault" (path resolve $vroot12/agent-vault/global/claude/memory) (path resolve $chome12/memory)
check "dangling: the link resolves again" true (test -d $chome12/memory; and echo true; or echo false)

set -e __fish_agent_vault_dir
set -e __fish_agent_vault_claude_root
set -g __fish_agent_vault_claude_home $HERMETIC_HOME/claude
set -g __fish_agent_vault_agy_root $HERMETIC_HOME/agy

#   ──────────────── agents-init reports what really happened ─────────────
# agents-init shares _agents_repo_sync with agents-vault and shared its
# false zero too: it ended on a branchless `if` with no arm for a failed
# commit, so fish resolved the function to 0 and a rejected commit was
# reported as a successful sync. It also runs on every agent launch, so it
# has to keep committing with the remote out of reach.
echo ""
echo "== agents-init (commit reporting) =="

set -l ip (new_repo)
pushd $ip >/dev/null
set -l irc (agents-init --silent 2>/dev/null; echo $status)
popd >/dev/null
check "agents-init: scaffolds and returns 0" 0 "$irc"
check "agents-init: committed the AGENTS repo" true (test (git -C $ip/AGENTS rev-list --count HEAD) -ge 1; and echo true; or echo false)

# Offline. The pull that used to run here blocked the launch until the
# remote timed out and then took the commit down with it, so an agent's
# edits went unrecorded on every launch away from the network.
set -l ibare (mktemp -d); set -ga TMPDIRS $ibare
git init -q --bare $ibare
git -C $ip/AGENTS remote add origin $ibare
git -C $ip/AGENTS push -q -u origin HEAD 2>/dev/null
git -C $ip/AGENTS remote set-url origin /nonexistent/unreachable.git
echo note >$ip/AGENTS/devlogs/offline.md
set -l ihead (git -C $ip/AGENTS rev-list --count HEAD)
pushd $ip >/dev/null
set -l iorc (agents-init --silent 2>/dev/null; echo $status)
popd >/dev/null
check "agents-init: offline run returns 0" 0 "$iorc"
check "agents-init: offline run still committed" (math $ihead + 1) (git -C $ip/AGENTS rev-list --count HEAD)
check "agents-init: the offline commit holds the file" note (git -C $ip/AGENTS show HEAD:devlogs/offline.md 2>/dev/null)

# A rejected commit records nothing, so reporting success tells the user
# their agent's edits were captured when they were not. agents-init points
# core.hooksPath at .agents-tools/hooks itself, which is where a real
# secret scanner would sit, and the shims are only refreshed when their
# version marker moves -- so this replacement survives the run under test.
printf '#!/bin/sh\nexit 1\n' >$ip/AGENTS/.agents-tools/hooks/pre-commit
chmod +x $ip/AGENTS/.agents-tools/hooks/pre-commit
echo blocked >$ip/AGENTS/devlogs/blocked.md
set -l ibhead (git -C $ip/AGENTS rev-list --count HEAD)
set -l ierr (mktemp); set -ga TMPDIRS $ierr
pushd $ip >/dev/null
set -l ibrc (agents-init --silent 2>$ierr; echo $status)
popd >/dev/null
check "agents-init: a rejected commit returns non-zero" 1 "$ibrc"
check "agents-init: a rejected commit says nothing was recorded" true (string match -q '*nothing recorded*' -- (cat $ierr); and echo true; or echo false)
check "agents-init: a rejected commit really recorded nothing" $ibhead (git -C $ip/AGENTS rev-list --count HEAD)

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
