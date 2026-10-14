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

#   ─────────────────── vault .gitignore line-merge ───────────────────
section "_agents_vault_ensure_gitignore: create"
set -l gv (mkscratch)
set -l res (_agents_vault_ensure_gitignore $gv)
check "absent: created" created "$res"
check "created file mode is 600" 600 (stat -c %a $gv/.gitignore)
for rule in '*.db' '*.db-wal' '*.db-shm' /.adopt-stash /.migrate-stash
    check "created file carries $rule" true (grep -qxF -- "$rule" $gv/.gitignore; and echo true; or echo false)
end
set -l sum (cksum <$gv/.gitignore)
set res (_agents_vault_ensure_gitignore $gv)
check "complete file: nothing printed" "" "$res"
check "complete file: byte-identical" "$sum" (cksum <$gv/.gitignore)

section "_agents_vault_ensure_gitignore: merge"
set -l mv (mkscratch)
printf '%s\n' '# mine' 'notes.tmp' '*.db' '!keep.db' scratch/ >$mv/.gitignore
chmod 640 $mv/.gitignore
set res (_agents_vault_ensure_gitignore $mv)
check "partial file: merged" merged "$res"
check "user lines kept in place at the top" "# mine notes.tmp *.db !keep.db scratch/" (head -5 $mv/.gitignore | string join ' ')
check "existing *.db not duplicated" 1 (grep -cxF -- '*.db' $mv/.gitignore)
for rule in '*.db-wal' '*.db-shm' /.adopt-stash /.migrate-stash
    check "missing $rule appended once" 1 (grep -cxF -- "$rule" $mv/.gitignore)
end
check "negation line preserved" true (grep -qxF -- '!keep.db' $mv/.gitignore; and echo true; or echo false)
check "file mode not changed by merge" 640 (stat -c %a $mv/.gitignore)
set sum (cksum <$mv/.gitignore)
set res (_agents_vault_ensure_gitignore $mv)
check "merge is idempotent: nothing printed" "" "$res"
check "merge is idempotent: byte-identical" "$sum" (cksum <$mv/.gitignore)

# No trailing newline on the user's last line: the block must not fuse with it.
set -l nv (mkscratch)
printf userrule >$nv/.gitignore
set res (_agents_vault_ensure_gitignore $nv)
check "no trailing newline: merged" merged "$res"
check "user's last rule intact" userrule (head -1 $nv/.gitignore)
check "rules appended on their own lines" 1 (grep -cxF -- /.migrate-stash $nv/.gitignore)

# An empty file is a file: merged, not mistaken for absent.
set -l ev (mkscratch)
: >$ev/.gitignore
set res (_agents_vault_ensure_gitignore $ev)
check "empty file: merged" merged "$res"

# The merged rules actually do their job in git.
set -l gr (new_repo)
printf '%s\n' x >$gr/.gitignore
_agents_vault_ensure_gitignore $gr >/dev/null
touch $gr/data.db $gr/data.db-wal $gr/data.db-shm $gr/.adopt-stash $gr/.migrate-stash $gr/ok.md
check "merged rules ignore db, sidecars and stashes" ok.md (git -C $gr status --porcelain --untracked-files=all | string match -rv '\.gitignore' | string replace -r '^\?\? ' '')

# A write that cannot happen is reported, not swallowed.
set -l rv (mkscratch)
mkdir $rv/.gitignore
_agents_vault_ensure_gitignore $rv >/dev/null 2>&1
check "unwritable .gitignore: exit 1" 1 $status
_agents_vault_ensure_gitignore >/dev/null 2>&1
check "no vault argument: exit 1" 1 $status

section "agents-vault: existing vault gains missing .gitignore rules"
set -l gvroot (mkscratch)
set -l gcroot (mkscratch)
set -l gagy (mkscratch)
set -g __fish_agent_vault_dir $gvroot/agent-vault
set -g __fish_agent_vault_claude_root $gcroot
set -g __fish_agent_vault_agy_root $gagy
set -g proj (new_repo https://git.rootiest.dev/rootiest/gi.git)
run_vault --silent
# Rewind the file to what an older version scaffolded.
printf '%s\n' '*.db' >$gvroot/agent-vault/.gitignore
git -C $gvroot/agent-vault add -A
git -C $gvroot/agent-vault commit -qm old-template
set out (run_vault --quiet)
for rule in '*.db-wal' '*.db-shm' /.adopt-stash /.migrate-stash
    check "ordinary run appended $rule" 1 (grep -cxF -- "$rule" $gvroot/agent-vault/.gitignore)
end
check "the merge is reported by --quiet" true (test -n "$out"; and echo true; or echo false)
check "the merge was committed" "" (git -C $gvroot/agent-vault status --porcelain)
set out (run_vault --quiet)
check "next run is silent" "" "$out"

# A fresh scaffold is unchanged from before the refactor.
set -l fresh (mkscratch)
set -g __fish_agent_vault_dir $fresh/agent-vault
run_vault --silent
check "fresh vault scaffolds the full template" 14 (count (cat $fresh/agent-vault/.gitignore))
check "fresh vault .gitignore is 600" 600 (stat -c %a $fresh/agent-vault/.gitignore)

#   ─────────────────── bounded, non-interactive network ───────────────────
section _agents_repo_net_git

# A stub standing in for ssh. git runs it as `sh -c "$GIT_SSH_COMMAND host
# git-upload-pack ..."`, so it records exactly what a real ssh would have
# been given -- arguments and the prompt-related environment -- and then
# sleeps, which is the blackholed-address shape: connected to nothing,
# answering nothing, never failing. The sleep is short and `exec`'d so
# nothing outlives the suite for long.
set -l stubdir (mkscratch)
set -l dump $stubdir/seen
printf '%s\n' '#!/bin/sh' \
    "printf 'ARGS:%s\\n' \"\$*\" >>$dump" \
    "printf 'TERMPROMPT:%s\\nASKPASS:%s\\nSSHASKPASS:%s\\n' \"\$GIT_TERMINAL_PROMPT\" \"\$GIT_ASKPASS\" \"\$SSH_ASKPASS\" >>$dump" \
    'exec sleep 8' >$stubdir/ssh-stub
chmod +x $stubdir/ssh-stub

set -l nr (new_repo)
git -C $nr remote add origin ssh://blackhole.invalid/repo.git

set -l t0 (date +%s)
GIT_SSH_COMMAND=$stubdir/ssh-stub _agents_repo_net_git $nr 1 fetch -q origin >/dev/null 2>&1
set -l rc $status
set -l elapsed (math (date +%s) - $t0)
check "blackholed remote: killed by the cap (124)" 124 $rc
check "blackholed remote: returned well before the stub's sleep ends" true (test $elapsed -lt 6; and echo true; or echo false)
check "ssh was run in BatchMode" true (grep -q 'BatchMode=yes' $dump; and echo true; or echo false)
check "ssh was given a connect timeout" true (grep -q 'ConnectTimeout=10' $dump; and echo true; or echo false)
check "git credential prompt closed (GIT_TERMINAL_PROMPT=0)" true (grep -q '^TERMPROMPT:0$' $dump; and echo true; or echo false)
check "GIT_ASKPASS neutralised" true (grep -q '^ASKPASS:true$' $dump; and echo true; or echo false)
check "SSH_ASKPASS neutralised" true (grep -q '^SSHASKPASS:true$' $dump; and echo true; or echo false)

# The user's own ssh command is extended, not replaced.
rm -f $dump
GIT_SSH_COMMAND="$stubdir/ssh-stub -i /nonexistent/key" _agents_repo_net_git $nr 1 fetch -q origin >/dev/null 2>&1
check "GIT_SSH_COMMAND options preserved" true (grep -q -- '-i /nonexistent/key' $dump; and echo true; or echo false)
check "...and BatchMode appended" true (grep -q 'BatchMode=yes' $dump; and echo true; or echo false)

rm -f $dump
git -C $nr config core.sshCommand "$stubdir/ssh-stub -i /nonexistent/cfg"
env -u GIT_SSH_COMMAND fish -c 'source $argv[1]; _agents_repo_net_git $argv[2] 1 fetch -q origin' -- $repo_root/functions/_agents_repo_net_git.fish $nr >/dev/null 2>&1
check "core.sshCommand honoured when the env is unset" true (grep -q -- '-i /nonexistent/cfg' $dump; and echo true; or echo false)
git -C $nr config --unset core.sshCommand

# A reachable (local) remote works and reports success.
set -l bare (mkscratch)
git init -q --bare $bare
git -C $nr remote set-url origin $bare
_agents_repo_net_git $nr 20 fetch -q origin
check "local remote: success" 0 $status

# No timeout(1): nothing is run, and the status says why.
begin
    set -lx PATH /nonexistent
    _agents_repo_net_git $nr 20 fetch -q origin
    set -l norc $status
    check "no timeout(1): refused with 4" 4 $norc
end
_agents_repo_net_git $nr >/dev/null 2>&1
check "missing arguments: 2" 2 $status

#   ───────────────────── agents-init --pull (option a) ─────────────────────
section "agents-init --pull"

# A project whose AGENTS/ sub-repo has a local bare repository as its
# upstream. Nothing here can reach the network.
function pull_fixture
    set -l p (new_repo)
    git -C $p commit -q --allow-empty -m init
    pushd $p >/dev/null
    agents-init --silent >/dev/null 2>&1
    popd >/dev/null
    set -l bare (mkscratch)
    git init -q --bare $bare
    git -C $p/AGENTS remote add origin $bare
    git -C $p/AGENTS push -q -u origin HEAD 2>/dev/null
    set -l clone (mkscratch)
    git clone -q $bare $clone/c
    git -C $clone/c config user.email t@t
    git -C $clone/c config user.name t
    git -C $clone/c config core.hooksPath /dev/null
    printf '%s\n' $p $bare $clone/c
end

# The helper on its own: the exit codes agents-init maps to messages.
_agents_init_pull (mkscratch) >/dev/null 2>&1
check "_agents_init_pull: not a repository: 1" 1 $status
set -l hp_np (new_repo)
set -l hp_out (_agents_init_pull $hp_np)
check "_agents_init_pull: no upstream: exit 0" 0 $status
check "_agents_init_pull: no upstream: names it" no-upstream "$hp_out"
set -l hp_rb (new_repo)
mkdir -p $hp_rb/.git/rebase-merge
_agents_init_pull $hp_rb >/dev/null 2>&1
check "_agents_init_pull: rebase in progress: 3" 3 $status
check "_agents_init_pull: rebase left alone" true (test -d $hp_rb/.git/rebase-merge; and echo true; or echo false)

set -l fx (pull_fixture)
set -l pp $fx[1]
set -l pclone $fx[3]
echo upstream >$pclone/from-upstream.md
git -C $pclone add -A
git -C $pclone commit -qm 'upstream change'
git -C $pclone push -q origin HEAD 2>/dev/null

# Without the flag, a run never touches the remote: the upstream change is
# not there, however long the user waits.
pushd $pp >/dev/null
agents-init --silent
set -l plain_rc $status
popd >/dev/null
check "plain run succeeds" 0 $plain_rc
check "plain run does not pull" false (test -e $pp/AGENTS/from-upstream.md; and echo true; or echo false)

# A local edit makes the histories diverge, which is the normal case:
# agents-init commits on every launch.
echo local >$pp/AGENTS/local-note.md
pushd $pp >/dev/null
set -l out (agents-init --pull)
set -l rc $status
popd >/dev/null
check "--pull exits 0" 0 $rc
check "--pull reports the pull" true (string match -q '*Pulled AGENTS*' -- "$out"; and echo true; or echo false)
check "upstream file arrived" upstream (cat $pp/AGENTS/from-upstream.md)
check "local file kept" local (cat $pp/AGENTS/local-note.md)
check "no rebase left behind" false (test -d $pp/AGENTS/.git/rebase-merge; and echo true; or echo false)
check "worktree committed and clean" "" (git -C $pp/AGENTS status --porcelain)
check "local commits sit on top of upstream's" true (git -C $pp/AGENTS merge-base --is-ancestor origin/main HEAD; and echo true; or echo false)

# Already current.
pushd $pp >/dev/null
set out (agents-init --pull)
set rc $status
popd >/dev/null
check "--pull when current: exit 0" 0 $rc
check "--pull when current says so" true (string match -q '*up to date*' -- "$out"; and echo true; or echo false)

# --quiet prints one line when it pulled and none otherwise.
echo more >$pclone/more.md
git -C $pclone add -A
git -C $pclone commit -qm more
git -C $pclone push -q origin HEAD 2>/dev/null
pushd $pp >/dev/null
set out (agents-init --pull --quiet)
popd >/dev/null
check "--pull --quiet reports a change" true (test -n "$out"; and echo true; or echo false)
pushd $pp >/dev/null
set out (agents-init --pull --quiet)
popd >/dev/null
check "--pull --quiet is silent when current" "" "$out"

# A conflicting rebase is aborted and nothing is lost.
echo theirs >$pclone/clash.md
git -C $pclone add -A
git -C $pclone commit -qm 'clash upstream'
git -C $pclone push -q origin HEAD 2>/dev/null
echo ours >$pp/AGENTS/clash.md
pushd $pp >/dev/null
set -l head_before_conflict (git -C $pp/AGENTS rev-parse HEAD)
agents-init --pull --silent 2>/dev/null
set rc $status
popd >/dev/null
check "conflict: exit 1" 1 $rc
check "conflict: no rebase left in progress" false (test -d $pp/AGENTS/.git/rebase-merge -o -d $pp/AGENTS/.git/rebase-apply; and echo true; or echo false)
check "conflict: local commit intact" true (git -C $pp/AGENTS cat-file -e HEAD:clash.md 2>/dev/null; and echo true; or echo false)
check "conflict: local content intact" ours (git -C $pp/AGENTS show HEAD:clash.md)

# An unreachable remote fails fast, loudly, and keeps the local commit.
set -l fx2 (pull_fixture)
git -C $fx2[1]/AGENTS remote set-url origin /nonexistent/remote.git
echo keep >$fx2[1]/AGENTS/keep.md
pushd $fx2[1] >/dev/null
set -l t0 (date +%s)
agents-init --pull --silent 2>/dev/null
set rc $status
popd >/dev/null
check "unreachable remote: exit 1" 1 $rc
check "unreachable remote: fast" true (test (math (date +%s) - $t0) -lt 20; and echo true; or echo false)
check "unreachable remote: local edit still committed" true (git -C $fx2[1]/AGENTS cat-file -e HEAD:keep.md 2>/dev/null; and echo true; or echo false)

# No upstream at all is not an error.
set -l np (new_repo)
git -C $np commit -q --allow-empty -m init
pushd $np >/dev/null
set out (agents-init --pull)
set rc $status
popd >/dev/null
check "no upstream: exit 0" 0 $rc
check "no upstream: says so" true (string match -q '*no upstream*' -- "$out"; and echo true; or echo false)

# The cap and the no-prompt environment are covered on _agents_repo_net_git
# above. Here only that an ssh remote that fails outright surfaces as exit 1
# through the whole command.
printf '%s\n' '#!/bin/sh' 'exit 255' >$stubdir/ssh-fail
chmod +x $stubdir/ssh-fail
git -C $fx2[1]/AGENTS remote set-url origin ssh://blackhole.invalid/repo.git
pushd $fx2[1] >/dev/null
GIT_SSH_COMMAND=$stubdir/ssh-fail agents-init --pull --silent 2>/dev/null
set rc $status
popd >/dev/null
check "failing ssh remote: exit 1" 1 $rc

set -e __fish_agent_vault_dir
set -e __fish_agent_vault_claude_root
cleanup
report
