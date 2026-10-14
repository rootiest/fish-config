#!/usr/bin/env fish
# Copyright (C) 2026 Rootiest
# SPDX-License-Identifier: AGPL-3.0-or-later
# MODE: isolated
#
# Hermetic tests for the agents-vault / agents-init limitations tracked in
# #208: agy knowledge mirroring (deletions propagate, and only inside the
# mirror), the vault .gitignore line-merge for existing vaults, and the
# opt-in freshness paths for an AGENTS/ sub-repo with an upstream. Every
# fixture lives under mktemp; no test touches the network or the real home.
#
# Usage: fish tests/test-agents-vault-limits.fish

source (realpath (dirname (status filename)))/lib.fish
set -p fish_function_path $repo_root/functions

set -g TMPDIRS

# Identity, signing and branch name come from the environment so a runner
# with no git config behaves like a developer machine (same reasoning as
# tests/test-agents-vault.fish).
set -gx GIT_AUTHOR_NAME t
set -gx GIT_AUTHOR_EMAIL t@t
set -gx GIT_COMMITTER_NAME t
set -gx GIT_COMMITTER_EMAIL t@t
set -gx GIT_CONFIG_COUNT 2
set -gx GIT_CONFIG_KEY_0 commit.gpgsign
set -gx GIT_CONFIG_VALUE_0 false
set -gx GIT_CONFIG_KEY_1 init.defaultBranch
set -gx GIT_CONFIG_VALUE_1 main

function mkscratch
    set -l d (mktemp -d)
    set -ga TMPDIRS $d
    printf '%s\n' $d
end

function new_repo --argument-names url
    set -l d (mkscratch)
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

function yes_no
    if test $argv[1] = ok
        echo true
    else
        echo false
    end
end

# A throwaway home, so that anything that ignores an override lands here
# and not in the real one.
set -g HERMETIC_HOME (mkscratch)
set -gx HOME $HERMETIC_HOME
set -gx XDG_DATA_HOME $HERMETIC_HOME/.local/share
set -gx XDG_CONFIG_HOME $HERMETIC_HOME/.config
mkdir -p $HERMETIC_HOME/claude $HERMETIC_HOME/agy
set -g __fish_agent_vault_claude_home $HERMETIC_HOME/claude
set -g __fish_agent_vault_agy_root $HERMETIC_HOME/agy

#   ─────────────────────── agy knowledge mirroring ───────────────────────
section "agents-vault: agy knowledge is mirrored"

set -l vroot (mkscratch)
set -l croot (mkscratch)
set -l agy (mkscratch)
set -l outside (mkscratch)
set -g __fish_agent_vault_dir $vroot/agent-vault
set -g __fish_agent_vault_claude_root $croot
set -g __fish_agent_vault_agy_root $agy
set -l vk $vroot/agent-vault/global/agy/knowledge

mkdir -p $agy/knowledge/sub $agy/knowledge/gone
echo a >$agy/knowledge/a.md
echo b >$agy/knowledge/b.md
echo c >$agy/knowledge/sub/c.md
echo '{"d":1}' >$agy/knowledge/sub/d.json
echo e >$agy/knowledge/gone/e.md
echo '{"s":1}' >$agy/settings.json

set -g proj (new_repo https://git.rootiest.dev/rootiest/limits.git)
function run_vault
    pushd $proj >/dev/null
    agents-vault $argv
    set -l rc $status
    popd >/dev/null
    return $rc
end

run_vault --silent
check "first run mirrors every note" 5 (command find $vk -type f | count)

# Things the mirror must never touch: other vault subtrees, settings.json,
# the vault's own files. Planted before any prune runs.
set -l vault $vroot/agent-vault
echo keep >$vault/global/agy/settings-sibling.txt
mkdir -p $vault/global/claude/memory
echo keep >$vault/global/claude/memory/m.md
echo outside-secret >$outside/precious.md
mkdir -p $outside/dir
echo outside-secret >$outside/dir/deep.md
git -C $vault add -A
git -C $vault commit -qm fixture

# Deleted upstream -> deleted from the vault, and committed as deleted.
rm $agy/knowledge/b.md $agy/knowledge/sub/d.json $agy/knowledge/gone/e.md
set -l out (run_vault --quiet)
check "deleted note pruned from the vault" false (test -e $vk/b.md; and echo true; or echo false)
check "deleted json pruned from nested dir" false (test -e $vk/sub/d.json; and echo true; or echo false)
check "surviving note kept" a (cat $vk/a.md)
check "surviving nested note kept" c (cat $vk/sub/c.md)
check "directory emptied by pruning removed" false (test -e $vk/gone; and echo true; or echo false)
check "populated directory kept" true (test -d $vk/sub; and echo true; or echo false)
check "prune is reported by --quiet" true (test -n "$out"; and echo true; or echo false)
check "pruned note absent from HEAD" false (git -C $vault cat-file -e HEAD:global/agy/knowledge/b.md 2>/dev/null; and echo true; or echo false)
check "pruned note still in history" true (git -C $vault cat-file -e HEAD~1:global/agy/knowledge/b.md 2>/dev/null; and echo true; or echo false)
check "worktree clean after prune" "" (git -C $vault status --porcelain)
check "settings.json outside the mirror untouched" '{"s":1}' (cat $vault/global/agy/settings.json)
check "sibling of knowledge/ untouched" keep (cat $vault/global/agy/settings-sibling.txt)
check "global claude memory untouched" keep (cat $vault/global/claude/memory/m.md)

# Idempotent and quiet when nothing changed.
set out (run_vault --quiet)
check "steady-state run prints nothing" "" "$out"

#   ── stale shapes an earlier version could have left behind ──
# A dereferenced alias, a leaked dot-file and a non-allowlisted file all sit
# in the mirror with no qualifying source: they must go.
ln -s $outside/precious.md $agy/knowledge/alias.md
echo old-deref >$vk/alias.md
echo leaked >$vk/.credentials.json
echo db >$vk/conversations.db
mkdir -p $vk/.hidden
echo leaked >$vk/.hidden/x.json
run_vault --silent
for stale in alias.md .credentials.json conversations.db .hidden
    check "stale $stale pruned" false (test -e $vk/$stale; and echo true; or echo false)
end
check "symlink target outside untouched" outside-secret (cat $outside/precious.md)

#   ── never follows a link, never leaves the mirror ──
ln -s $outside/precious.md $vk/evil.md
ln -s $outside/dir $vk/dirlink
run_vault --silent
check "planted file link removed" false (test -L $vk/evil.md; and echo true; or echo false)
check "planted dir link removed" false (test -L $vk/dirlink; and echo true; or echo false)
check "file behind file link intact" outside-secret (cat $outside/precious.md)
check "files behind dir link intact" outside-secret (cat $outside/dir/deep.md)

# A source that has the same name as a mirror dir but is a symlink to a
# directory is not a source: the mirror's copy of it goes.
mkdir -p $vk/viadir
echo stale >$vk/viadir/n.md
ln -s $outside/dir $agy/knowledge/viadir
run_vault --silent
check "files under a now-symlinked source dir pruned" false (test -e $vk/viadir; and echo true; or echo false)
check "symlink-dir target intact" outside-secret (cat $outside/dir/deep.md)
rm $agy/knowledge/viadir $agy/knowledge/alias.md

#   ── an absent or empty source must not wipe the vault ──
section "agents-vault: absent or empty source does not wipe the vault"
set -l before (command find $vk -type f | sort | string join ' ')
test -n "$before"; or echo "  (fixture error: empty mirror)"

# Unmounted / absent store: the directory is simply gone.
mv $agy/knowledge $agy/knowledge.away
run_vault --silent
check "missing source: vault kept" "$before" (command find $vk -type f | sort | string join ' ')

# Mountpoint present, nothing mounted on it.
mkdir $agy/knowledge
run_vault --silent
check "empty source: vault kept" "$before" (command find $vk -type f | sort | string join ' ')

# Present but holds nothing that qualifies (only machinery).
echo x >$agy/knowledge/knowledge.lock
run_vault --silent
check "non-qualifying source: vault kept" "$before" (command find $vk -type f | sort | string join ' ')
check "no deletion was committed" "" (git -C $vault status --porcelain)

# Unreadable source: refused, not read as "empty". Skipped as root, which
# reads everything.
if test (id -u) -ne 0
    chmod 000 $agy/knowledge
    run_vault --silent
    chmod 755 $agy/knowledge
    check "unreadable source: vault kept" "$before" (command find $vk -type f | sort | string join ' ')
end
rm -rf $agy/knowledge
mv $agy/knowledge.away $agy/knowledge

# Restored store prunes normally again.
rm $agy/knowledge/a.md
run_vault --silent
check "after restore, deletions mirror again" false (test -e $vk/a.md; and echo true; or echo false)
check "after restore, remaining note kept" c (cat $vk/sub/c.md)

#   ── the helper in isolation ──
section "_agents_vault_prune_agy: refusals"
set -l hv (mkscratch)
set -l hs (mkscratch)
mkdir -p $hv/global/agy/knowledge
echo keepme >$hv/global/agy/knowledge/n.md
_agents_vault_prune_agy $hv $hs/nonexistent >/dev/null
check "absent source refused" 2 $status
_agents_vault_prune_agy $hv >/dev/null 2>&1
check "wrong arity refused" 2 $status
_agents_vault_prune_agy $hv $hs >/dev/null
check "empty source refused" 2 $status
check "refusal removed nothing" keepme (cat $hv/global/agy/knowledge/n.md)

# A mirror directory that is itself a link is refused outright.
set -l hv2 (mkscratch)
mkdir -p $hv2/global/agy
mkdir -p $outside/mirror
echo outside-secret >$outside/mirror/stale.md
ln -s $outside/mirror $hv2/global/agy/knowledge
echo keep >$hs/other.md
_agents_vault_prune_agy $hv2 $hs >/dev/null
check "symlinked mirror dir refused" 2 $status
check "nothing behind the symlinked mirror touched" outside-secret (cat $outside/mirror/stale.md)

# Nothing mirrored yet is not an error.
set -l hv3 (mkscratch)
set -l n (_agents_vault_prune_agy $hv3 $hs)
check "no mirror yet: ok" 0 $status
check "no mirror yet: nothing removed" 0 $n

# Count reporting.
echo a >$hs/a.md
echo a >$hv/global/agy/knowledge/a.md
echo z >$hv/global/agy/knowledge/z.md
set n (_agents_vault_prune_agy $hv $hs)
check "prunes stale, reports count" 0 $status
check "count of removed files" 2 $n
check "survivor kept" a (cat $hv/global/agy/knowledge/a.md)

set -e __fish_agent_vault_dir
set -e __fish_agent_vault_claude_root
cleanup
report
