#!/usr/bin/env fish
# Copyright (C) 2026 Rootiest
# SPDX-License-Identifier: AGPL-3.0-or-later
#
# Hermetic tests for agents-init's public-mode helpers and the local slug
# formula: _agents_init_sync_public (settles one directory's public and
# private instruction files), _agents_init_migrate_public (converts a
# private-mode project to public mode) and _agents_repo_local_slug.
# test-agents-init.fish covers the private-mode sync helper; this suite is
# the public-mode counterpart.
#
# Runs isolated (no `# MODE:` marker). Both public-mode helpers move,
# rewrite and delete files and run git in two repositories, so every case
# builds real throwaway repos inside one mktemp -d sandbox, next to a
# sentinel directory that must come through untouched, and every symlink
# they create is checked to resolve inside its own project.
#
# Usage: fish tests/test-agents-init-helpers.fish

source (realpath (dirname (status filename)))/lib.fish
set -p fish_function_path $repo_root/functions

set -gx GIT_AUTHOR_NAME t
set -gx GIT_AUTHOR_EMAIL t@t
set -gx GIT_COMMITTER_NAME t
set -gx GIT_COMMITTER_EMAIL t@t
set -gx GIT_CONFIG_COUNT 3
set -gx GIT_CONFIG_KEY_0 commit.gpgsign
set -gx GIT_CONFIG_VALUE_0 false
set -gx GIT_CONFIG_KEY_1 init.defaultBranch
set -gx GIT_CONFIG_VALUE_1 main
set -gx GIT_CONFIG_KEY_2 core.hooksPath
set -gx GIT_CONFIG_VALUE_2 /dev/null

set -g sandbox (path resolve (mktemp -d))
# Stop git's upward repo discovery at the sandbox, so a directory that is
# meant not to be a repo never finds one above it.
set -gx GIT_CEILING_DIRECTORIES $sandbox

# Sentinel: a sibling of every project, snapshotted now and compared at
# the end. Anything a helper wrote "outside" would most plausibly land here.
mkdir -p $sandbox/outside
echo keep >$sandbox/outside/AGENTS.md
ln -s ../outside/AGENTS.md $sandbox/outside/link.md
function snapshot
    find $sandbox/outside -printf '%P %y %s %l\n' | sort | string collect
end
set -g outside_before (snapshot)

set -g n 0
function new_repo
    set -g n (math $n + 1)
    set -l d $sandbox/p$n
    mkdir -p $d
    git -C $d init -q
    printf '%s\n' $d
end

function new_agents --argument-names root
    mkdir -p $root/AGENTS
    git -C $root/AGENTS init -q
end

function yes_no
    if $argv
        echo true
    else
        echo false
    end
end

# Every symlink under <root> resolves (fully) to a path inside <root>.
function links_contained --argument-names root
    for l in (find $root -name .git -prune -o -type l -print)
        set -l t (path resolve $l)
        string match -q -- "$root/*" $t; or return 1
    end
    return 0
end

#   ──────────────────────── _agents_repo_local_slug ───────────────────

section _agents_repo_local_slug

mkdir -p "$sandbox/My Project!" $sandbox/plain
set -l rp (path resolve "$sandbox/My Project!")
set -l want_hash (printf '%s' $rp | sha256sum | string sub -l 8)
check "sanitized basename + 8 hex of sha256(realpath)" "local-my-project--$want_hash" (_agents_repo_local_slug "$sandbox/My Project!")
check "exits 0" 0 (_agents_repo_local_slug $sandbox/plain >/dev/null; echo $status)
check format true (yes_no string match -qr '^local-[a-z0-9._-]+-[0-9a-f]{8}$' -- (_agents_repo_local_slug $sandbox/plain))

set -l abs (_agents_repo_local_slug $sandbox/plain)
cd $sandbox
set -l relslug (_agents_repo_local_slug plain)
cd $repo_root
check "relative path gives the same slug as absolute" $abs $relslug
ln -s plain $sandbox/plain-link
check "symlinked path gives the target's slug" $abs (_agents_repo_local_slug $sandbox/plain-link)
check "trailing slash does not change it" $abs (_agents_repo_local_slug $sandbox/plain/)
mkdir -p $sandbox/a/plain
check "same basename, different dir -> different slug" false (yes_no test $abs = (_agents_repo_local_slug $sandbox/a/plain))
check "keeps . _ - in the basename" true (yes_no string match -q 'local-x.y_z-w-*' -- (_agents_repo_local_slug $sandbox/X.y_Z-w))
set -l out (_agents_repo_local_slug)
check "no argument -> 1" 1 $status
check "no argument prints nothing" "" "$out"
_agents_repo_local_slug ''
check "empty argument -> 1" 1 $status

#   ──────────────────────── _agents_init_sync_public ──────────────────

section "_agents_init_sync_public: fresh root"

set -l r (new_repo)
mkdir -p $r/AGENTS
set -l out (_agents_init_sync_public $r $r/AGENTS .)
check "exits 0" 0 $status
check "public AGENTS.md is the public starter" (_agents_init_stub --public | string collect) (string collect <$r/AGENTS.md)
check "public AGENTS.md is a real file" false (yes_no test -L $r/AGENTS.md)
check "private file is the local stub" (_agents_init_stub --local | string collect) (string collect <$r/AGENTS/AGENTS.local.md)
check "AGENTS.local.md links into the mirror" AGENTS/AGENTS.local.md (readlink $r/AGENTS.local.md)
check "mirror AGENTS.md links back to the public file" ../AGENTS.md (readlink $r/AGENTS/AGENTS.md)
check "mirror link resolves to the public file" (path resolve $r/AGENTS.md) (path resolve $r/AGENTS/AGENTS.md)
check "reports each change" 4 (count $out)
check "links stay inside the project" true (yes_no links_contained $r)

set -l out (_agents_init_sync_public $r $r/AGENTS .)
check "idempotent: exits 0" 0 $status
check "idempotent: prints nothing" "" "$out"

section "_agents_init_sync_public: existing public file is never touched"

set -l r (new_repo)
mkdir -p $r/AGENTS
echo "my public rules" >$r/AGENTS.md
_agents_init_sync_public $r $r/AGENTS . >/dev/null
check "exits 0" 0 $status
check "real AGENTS.md content kept" "my public rules" (cat $r/AGENTS.md)
check "mirror links to it" ../AGENTS.md (readlink $r/AGENTS/AGENTS.md)

section "_agents_init_sync_public: private-mode leftover is skipped"

set -l r (new_repo)
mkdir -p $r/AGENTS
echo private >$r/AGENTS/AGENTS.md
ln -s AGENTS/AGENTS.md $r/AGENTS.md
set -l err (_agents_init_sync_public $r $r/AGENTS . 2>&1 >/dev/null | string collect)
check "exits 0 (warned skip)" 0 $pipestatus[1]
check "warns and points at agents-init --public" true (yes_no string match -q '*agents-init --public*' -- "$err")
check "leftover link untouched" AGENTS/AGENTS.md (readlink $r/AGENTS.md)
check "private mirror content untouched" private (cat $r/AGENTS/AGENTS.md)
check "no AGENTS.local.md created" false (yes_no test -e $r/AGENTS.local.md -o -L $r/AGENTS.local.md)
check "no mirror AGENTS.local.md created" false (yes_no test -e $r/AGENTS/AGENTS.local.md)

section "_agents_init_sync_public: CLAUDE.md"

# Untracked real CLAUDE.md is private: it becomes the mirror's local file,
# never the public one.
set -l r (new_repo)
mkdir -p $r/AGENTS
echo "secret claude notes" >$r/CLAUDE.md
_agents_init_sync_public $r $r/AGENTS . >/dev/null
check "untracked: exits 0" 0 $status
check "untracked: moved to mirror AGENTS.local.md" "secret claude notes" (cat $r/AGENTS/AGENTS.local.md)
check "untracked: project CLAUDE.md gone" false (yes_no test -e $r/CLAUDE.md)
check "untracked: never reaches the public file" false (yes_no grep -q secret $r/AGENTS.md)
check "untracked: reachable via the local link" "secret claude notes" (cat $r/AGENTS.local.md)

# Tracked CLAUDE.md is the project's own: left alone.
set -l r (new_repo)
mkdir -p $r/AGENTS
echo tracked >$r/CLAUDE.md
git -C $r add CLAUDE.md
git -C $r commit -qm c
_agents_init_sync_public $r $r/AGENTS . >/dev/null
check "tracked: exits 0" 0 $status
check "tracked: CLAUDE.md untouched" tracked (cat $r/CLAUDE.md)
check "tracked: still a real file" false (yes_no test -L $r/CLAUDE.md)
check "tracked: mirror gets the stub, not the tracked content" (_agents_init_stub --local | string collect) (string collect <$r/AGENTS/AGENTS.local.md)

# A leftover CLAUDE.md symlink is removed.
set -l r (new_repo)
mkdir -p $r/AGENTS
ln -s AGENTS.md $r/CLAUDE.md
_agents_init_sync_public $r $r/AGENTS . >/dev/null
check "symlink: removed" false (yes_no test -L $r/CLAUDE.md)

# Untracked CLAUDE.md identical to the existing mirror file: dropped.
set -l r (new_repo)
mkdir -p $r/AGENTS
echo same >$r/AGENTS/AGENTS.local.md
echo same >$r/CLAUDE.md
_agents_init_sync_public $r $r/AGENTS . >/dev/null
check "identical: CLAUDE.md removed" false (yes_no test -e $r/CLAUDE.md)
check "identical: mirror kept" same (cat $r/AGENTS/AGENTS.local.md)

# Untracked CLAUDE.md that differs from the mirror: both left, warning.
set -l r (new_repo)
mkdir -p $r/AGENTS
echo mirror >$r/AGENTS/AGENTS.local.md
echo other >$r/CLAUDE.md
set -l err (_agents_init_sync_public $r $r/AGENTS . 2>&1 >/dev/null | string collect)
check "differs: exits 0" 0 $pipestatus[1]
check "differs: CLAUDE.md kept" other (cat $r/CLAUDE.md)
check "differs: mirror kept" mirror (cat $r/AGENTS/AGENTS.local.md)
check "differs: warns" true (yes_no string match -q '*resolve by hand*' -- "$err")

section "_agents_init_sync_public: real AGENTS.local.md in the project"

set -l r (new_repo)
mkdir -p $r/AGENTS
echo "agent wrote this" >$r/AGENTS.local.md
_agents_init_sync_public $r $r/AGENTS . >/dev/null
check "adopted: moved into the mirror" "agent wrote this" (cat $r/AGENTS/AGENTS.local.md)
check "adopted: replaced by a link" AGENTS/AGENTS.local.md (readlink $r/AGENTS.local.md)

set -l r (new_repo)
mkdir -p $r/AGENTS
echo same >$r/AGENTS/AGENTS.local.md
echo same >$r/AGENTS.local.md
_agents_init_sync_public $r $r/AGENTS . >/dev/null
check "identical: replaced by a link" AGENTS/AGENTS.local.md (readlink $r/AGENTS.local.md)

set -l r (new_repo)
mkdir -p $r/AGENTS
echo mirror >$r/AGENTS/AGENTS.local.md
echo project >$r/AGENTS.local.md
set -l err (_agents_init_sync_public $r $r/AGENTS . 2>&1 >/dev/null | string collect)
check "differs: exits 0" 0 $pipestatus[1]
check "differs: project file kept as a real file" project (cat $r/AGENTS.local.md)
check "differs: not replaced by a link" false (yes_no test -L $r/AGENTS.local.md)
check "differs: mirror kept" mirror (cat $r/AGENTS/AGENTS.local.md)
check "differs: warns" true (yes_no string match -q '*differ*' -- "$err")

# A wrong AGENTS.local.md link is repointed.
set -l r (new_repo)
mkdir -p $r/AGENTS
echo x >$r/AGENTS/AGENTS.local.md
ln -s elsewhere.md $r/AGENTS.local.md
_agents_init_sync_public $r $r/AGENTS . >/dev/null
check "stale local link repointed" AGENTS/AGENTS.local.md (readlink $r/AGENTS.local.md)

section "_agents_init_sync_public: mirror AGENTS.md"

set -l r (new_repo)
mkdir -p $r/AGENTS
echo "private stuff" >$r/AGENTS/AGENTS.md
set -l err (_agents_init_sync_public $r $r/AGENTS . 2>&1 >/dev/null | string collect)
check "real mirror file: exits 0" 0 $pipestatus[1]
check "real mirror file: never replaced" "private stuff" (cat $r/AGENTS/AGENTS.md)
check "real mirror file: not a link" false (yes_no test -L $r/AGENTS/AGENTS.md)
check "real mirror file: warns" true (yes_no string match -q '*private content*' -- "$err")

set -l r (new_repo)
mkdir -p $r/AGENTS
ln -s wrong.md $r/AGENTS/AGENTS.md
_agents_init_sync_public $r $r/AGENTS . >/dev/null
check "stale mirror link relinked" ../AGENTS.md (readlink $r/AGENTS/AGENTS.md)

section "_agents_init_sync_public: child directories"

set -l r (new_repo)
mkdir -p $r/AGENTS $r/functions
echo "fn rules" >$r/functions/AGENTS.md
set -l out (_agents_init_sync_public $r $r/AGENTS functions)
check "child: exits 0" 0 $status
check "child: mirror dir created" true (yes_no test -d $r/AGENTS/functions)
check "child: mirror link" ../../functions/AGENTS.md (readlink $r/AGENTS/functions/AGENTS.md)
check "child: mirror link resolves" "fn rules" (cat $r/AGENTS/functions/AGENTS.md)
check "child: no local stub invented" false (yes_no test -e $r/AGENTS/functions/AGENTS.local.md)
check "child: no local link invented" false (yes_no test -L $r/functions/AGENTS.local.md)
check "child: root untouched" false (yes_no test -e $r/AGENTS.md)

# Missing child public file stays missing (only the root gets a starter).
set -l r (new_repo)
mkdir -p $r/AGENTS $r/docs
_agents_init_sync_public $r $r/AGENTS docs >/dev/null
check "child without AGENTS.md: none created" false (yes_no test -e $r/docs/AGENTS.md)

# A user-created child local file gets its link; nested depth is right.
set -l r (new_repo)
mkdir -p $r/AGENTS/a/b $r/a/b
echo deep >$r/a/b/AGENTS.md
echo "deep private" >$r/AGENTS/a/b/AGENTS.local.md
_agents_init_sync_public $r $r/AGENTS a/b >/dev/null
check "nested: local link" ../../AGENTS/a/b/AGENTS.local.md (readlink $r/a/b/AGENTS.local.md)
check "nested: local link resolves" "deep private" (cat $r/a/b/AGENTS.local.md)
check "nested: mirror link" ../../../a/b/AGENTS.md (readlink $r/AGENTS/a/b/AGENTS.md)
check "nested: mirror link resolves" deep (cat $r/AGENTS/a/b/AGENTS.md)
check "nested: links stay inside the project" true (yes_no links_contained $r)

section "_agents_init_sync_public: argument and failure handling"

_agents_init_sync_public
check "no args -> 1" 1 $status
_agents_init_sync_public $sandbox/x $sandbox/x/AGENTS
check "missing rel -> 1" 1 $status

# The mirror cannot be created (AGENTS is a regular file): fail, not 0.
set -l r (new_repo)
echo "not a dir" >$r/AGENTS
_agents_init_sync_public $r $r/AGENTS functions >/dev/null 2>&1
check "mkdir failure -> 1" 1 $status
check "mkdir failure: blocking file untouched" "not a dir" (cat $r/AGENTS)

#   ─────────────────────── _agents_init_migrate_public ────────────────

section "_agents_init_migrate_public: preconditions refuse before any change"

function private_project
    set -l r (new_repo)
    new_agents $r
    _agents_init_stub >$r/AGENTS/AGENTS.md
    git -C $r/AGENTS add AGENTS.md
    git -C $r/AGENTS commit -qm init
    ln -s AGENTS/AGENTS.md $r/AGENTS.md
    printf '%s\n' $r
end

_agents_init_migrate_public
check "no args -> 1" 1 $status

# Not a git repository (GIT_CEILING_DIRECTORIES keeps git from looking up).
set -l r $sandbox/norepo
mkdir -p $r
new_agents $r
echo private >$r/AGENTS/AGENTS.md
set -l err (_agents_init_migrate_public $r $r/AGENTS 2>&1 | string collect)
check "not a repo: exits 1" 1 $pipestatus[1]
check "not a repo: says so" true (yes_no string match -q '*not a git repository*' -- "$err")
check "not a repo: mirror untouched" private (cat $r/AGENTS/AGENTS.md)
check "not a repo: no .mode" false (yes_no test -e $r/AGENTS/.mode)

# AGENTS/ is a plain directory inside the project's repo, not its own repo.
set -l r (new_repo)
mkdir -p $r/AGENTS
echo private >$r/AGENTS/AGENTS.md
_agents_init_migrate_public $r $r/AGENTS 2>/dev/null
check "AGENTS not a repo: exits 1" 1 $status
check "AGENTS not a repo: untouched" private (cat $r/AGENTS/AGENTS.md)
check "AGENTS not a repo: no .mode" false (yes_no test -e $r/AGENTS/.mode)

# Rebase in progress inside AGENTS/.
for kind in rebase-merge rebase-apply
    set -l r (private_project)
    mkdir -p $r/AGENTS/.git/$kind
    _agents_init_migrate_public $r $r/AGENTS 2>/dev/null
    check "$kind: exits 1" 1 $status
    check "$kind: mirror AGENTS.md not renamed" true (yes_no test -f $r/AGENTS/AGENTS.md -a ! -L $r/AGENTS/AGENTS.md)
    check "$kind: project link untouched" AGENTS/AGENTS.md (readlink $r/AGENTS.md)
end

# Staged change to an AGENTS.md in the project.
set -l r (private_project)
mkdir -p $r/sub
echo staged >$r/sub/AGENTS.md
git -C $r add sub/AGENTS.md
set -l err (_agents_init_migrate_public $r $r/AGENTS 2>&1 | string collect)
check "staged AGENTS.md: exits 1" 1 $pipestatus[1]
check "staged AGENTS.md: names it" true (yes_no string match -q '*sub/AGENTS.md*' -- "$err")
check "staged AGENTS.md: mirror not renamed" false (yes_no test -e $r/AGENTS/AGENTS.local.md)
check "staged AGENTS.md: still staged" sub/AGENTS.md (git -C $r diff --cached --name-only)

section "_agents_init_migrate_public: full migration"

set -l r (new_repo)
echo base >$r/README
git -C $r add README
git -C $r commit -qm base
set -l head_before (git -C $r rev-parse HEAD)
new_agents $r
# Root: a real private file with an edit directive naming its old path.
printf '%s\n' '# Private rules' '> directly to `AGENTS/AGENTS.md`**.' PRIVATE-ROOT-MARKER >$r/AGENTS/AGENTS.md
# Child: tracked, no directive.
mkdir -p $r/AGENTS/functions $r/functions
echo PRIVATE-FN-MARKER >$r/AGENTS/functions/AGENTS.md
# Child with a directive naming some other path: kept, warned about.
mkdir -p $r/AGENTS/docs $r/docs
printf '%s\n' '> ⚠️ **SYSTEM DIRECTIVE FOR AI AGENTS: FILE EDITING**' '> directly to `somewhere/else.md`**.' >$r/AGENTS/docs/AGENTS.md
git -C $r/AGENTS add -A
git -C $r/AGENTS commit -qm private
# Untracked child mirror file: moved plainly.
mkdir -p $r/AGENTS/scratch $r/scratch
echo PRIVATE-SCRATCH >$r/AGENTS/scratch/AGENTS.md
# Project-side private-mode links.
ln -s AGENTS/AGENTS.md $r/AGENTS.md
ln -s ../AGENTS/functions/AGENTS.md $r/functions/AGENTS.md
ln -s ../AGENTS/docs/AGENTS.md $r/docs/AGENTS.md
# docs/ also has... nothing else; scratch/ has no project link at all.
printf '%s\n' node_modules AGENTS.md \
    '#   ──────────────── Added by agents-init ──────────────────' \
    '#   agent instructions' AGENTS/ AGENTS.md CLAUDE.md \
    '#   ────────────────────────────────────────────────────────' \
    '*.log' >$r/.gitignore

set -l out (_agents_init_migrate_public $r $r/AGENTS 2>$sandbox/migrate.err)
set -l rc $status
set -l err (string collect <$sandbox/migrate.err)
check "exits 0" 0 $rc

check "root: private content now in AGENTS.local.md" true (yes_no grep -q PRIVATE-ROOT-MARKER $r/AGENTS/AGENTS.local.md)
check "root: directive retargeted" true (yes_no grep -qF '`AGENTS/AGENTS.local.md`' $r/AGENTS/AGENTS.local.md)
check "root: old directive path gone" false (yes_no grep -qF '`AGENTS/AGENTS.md`' $r/AGENTS/AGENTS.local.md)
check "root: rename is staged as a git rename" true (yes_no string match -q 'R*AGENTS.md*AGENTS.local.md' -- (git -C $r/AGENTS diff --cached -M --name-status | string match '*	AGENTS.local.md'))
check "root: public AGENTS.md is the public starter" (_agents_init_stub --public | string collect) (string collect <$r/AGENTS.md)
check "root: public AGENTS.md is a real file" false (yes_no test -L $r/AGENTS.md)
check "root: AGENTS.local.md link" AGENTS/AGENTS.local.md (readlink $r/AGENTS.local.md)
check "root: mirror AGENTS.md links to the public file" ../AGENTS.md (readlink $r/AGENTS/AGENTS.md)

check "functions: private content moved" PRIVATE-FN-MARKER (cat $r/AGENTS/functions/AGENTS.local.md)
check "functions: public starter for the child" (_agents_init_stub --public functions | string collect) (string collect <$r/functions/AGENTS.md)
check "functions: local link" ../AGENTS/functions/AGENTS.local.md (readlink $r/functions/AGENTS.local.md)
check "functions: mirror link" ../../functions/AGENTS.md (readlink $r/AGENTS/functions/AGENTS.md)

check "docs: unrelated directive kept as is" true (yes_no grep -qF '`somewhere/else.md`' $r/AGENTS/docs/AGENTS.local.md)
check "docs: warned to check by hand" true (yes_no string match -q '*docs/AGENTS.local.md has an edit directive*' -- "$err")

check "scratch (untracked): moved" PRIVATE-SCRATCH (cat $r/AGENTS/scratch/AGENTS.local.md)
check "scratch: public starter created" true (yes_no test -f $r/scratch/AGENTS.md -a ! -L $r/scratch/AGENTS.md)

for f in AGENTS.md functions/AGENTS.md docs/AGENTS.md scratch/AGENTS.md
    check "no private content in public $f" false (yes_no grep -q PRIVATE $r/$f)
end

set -l gi (string collect <$r/.gitignore)
check ".gitignore: block line rewritten, outside lines kept" (printf '%s\n' node_modules AGENTS.md \
    '#   ──────────────── Added by agents-init ──────────────────' \
    '#   agent instructions' AGENTS/ AGENTS.local.md CLAUDE.md \
    '#   ────────────────────────────────────────────────────────' \
    '*.log' | string collect) "$gi"
check ".mode is public" public (cat $r/AGENTS/.mode)
check "reports the mode change last" "→ Marked AGENTS/ as public mode" "$out[-1]"
check "nothing committed in the project" $head_before (git -C $r rev-parse HEAD)
check "nothing staged in the project" "" (git -C $r diff --cached --name-only | string collect)
check "links stay inside the project" true (yes_no links_contained $r)

section "_agents_init_migrate_public: re-run is harmless"

set -l out (_agents_init_migrate_public $r $r/AGENTS 2>/dev/null)
check "re-run: exits 0" 0 $status
check "re-run: only re-marks the mode" "→ Marked AGENTS/ as public mode" "$out"
check "re-run: private content intact" true (yes_no grep -q PRIVATE-ROOT-MARKER $r/AGENTS/AGENTS.local.md)
check "re-run: .gitignore unchanged" "$gi" (string collect <$r/.gitignore)

section "_agents_init_migrate_public: stub directive and conflicts"

# The mirror file is exactly the private-mode stub: replaced by the local
# stub (its directive cannot just be string-swapped).
set -l r (private_project)
_agents_init_migrate_public $r $r/AGENTS >/dev/null 2>&1
check "stub: exits 0" 0 $status
check "stub: becomes the local stub" (_agents_init_stub --local . | string collect) (string collect <$r/AGENTS/AGENTS.local.md)

# An existing AGENTS.local.md in the mirror blocks that directory's rename.
set -l r (private_project)
echo already >$r/AGENTS/AGENTS.local.md
set -l err (_agents_init_migrate_public $r $r/AGENTS 2>&1 >/dev/null | string collect)
check "existing local: exits 0 (skipped, not fatal)" 0 $pipestatus[1]
check "existing local: warns" true (yes_no string match -q '*already exists*resolve by hand*' -- "$err")
check "existing local: kept" already (cat $r/AGENTS/AGENTS.local.md)
check "existing local: mirror AGENTS.md not renamed" (_agents_init_stub | string collect) (string collect <$r/AGENTS/AGENTS.md)
check "existing local: project link untouched" AGENTS/AGENTS.md (readlink $r/AGENTS.md)

# A real, tracked project AGENTS.md is kept as it is.
set -l r (new_repo)
new_agents $r
echo PRIVATE >$r/AGENTS/AGENTS.md
git -C $r/AGENTS add AGENTS.md
git -C $r/AGENTS commit -qm p
echo "project's own" >$r/AGENTS.md
git -C $r add AGENTS.md
git -C $r commit -qm own
_agents_init_migrate_public $r $r/AGENTS >/dev/null 2>&1
check "real project AGENTS.md: exits 0" 0 $status
check "real project AGENTS.md: kept" "project's own" (cat $r/AGENTS.md)
check "real project AGENTS.md: private file moved" PRIVATE (cat $r/AGENTS/AGENTS.local.md)

#   ────────────────────────────── containment ─────────────────────────

section containment

check "sentinel outside the projects untouched" $outside_before (snapshot)
check "no AGENTS files written at the sandbox root" "" (find $sandbox -maxdepth 1 -name '*AGENTS*' | string collect)

rm -rf $sandbox
report
