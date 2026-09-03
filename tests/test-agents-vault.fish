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

cleanup
echo ""
echo (math $TESTS_RUN - $TESTS_FAILED)"/$TESTS_RUN passed"
exit $TESTS_FAILED
