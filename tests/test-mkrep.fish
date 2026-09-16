#!/usr/bin/env fish
# Copyright (C) 2026 Rootiest
# SPDX-License-Identifier: AGPL-3.0-or-later
#
# Coverage for mkrep: directory creation + cd + git init, plus its flag
# matrix (--clean/--strict interaction, --no-* precedence, remote linking
# and remote creation via a user command template).
#
# Runs isolated (no `# MODE:` marker), which run-tests.fish executes as its
# own `fish --no-config` process with a throwaway XDG_CONFIG_HOME. mkrep does
# real filesystem mutations and cds, so every case works inside its own
# mktemp -d sandbox and restores $PWD afterward -- a stray cd or a leftover
# sandbox would still leak into later cases in this same file.

source (realpath (dirname (status filename)))/lib.fish
set -p fish_function_path $repo_root/functions

# mkrep resolves a server from $GIT_SERVER plus
# $GITEA_URL/$GITEA_HOST/$GITLAB_URL/$GITLAB_HOST, and this repo doubles as a
# real ~/.config/fish where all of them are exported for day-to-day use. Left
# ambient, a bare `mkrep <dir>` with no remote flag takes the auto-create
# branch and contacts the live forge: that is how an empty `rootiest/repo` came
# to exist on git.rootiest.dev on 2026-09-14, and why these cases then passed
# standalone (the repo exists, so mkrep links instead of creating) while
# failing under run-tests.fish (throwaway XDG_CONFIG_HOME, so `tea` has no
# login). Neutralize all five for the whole suite.
#
# Empty reads the same as unset to mkrep, so this is a clean slate without
# erasing the caller's real globals, and every section that wants a server sets
# its own `set -lx GIT_SERVER ...`, which still wins. Each isolated suite runs
# as its own `fish --no-config` process, so these cannot leak to another suite.
set -gx GIT_SERVER ''
set -gx GITEA_URL ''
set -gx GITEA_HOST ''
set -gx GITLAB_URL ''
set -gx GITLAB_HOST ''

function _mkrep_sandbox
    set -l tmp (mktemp -d)
    # Resolve symlinks (e.g. macOS/NixOS /tmp) so path comparisons against
    # mkrep's own `path resolve` output agree.
    path resolve $tmp
end

section "mkrep: defaults"

set -l start $PWD
set -l base (_mkrep_sandbox)
set -l target $base/repo
mkrep $target >/dev/null
set -l code $status
check "default run exits 0" 0 $code
check "directory created" true (test -d $target; and echo true; or echo false)
check "cwd entered" $target (path resolve $PWD)
check "git repo initialized" true (test -d $target/.git; and echo true; or echo false)
cd $start
rm -rf $base

section "mkrep: --no-cd"

set -l base (_mkrep_sandbox)
set -l target $base/repo
mkrep --no-cd $target >/dev/null
check "--no-cd exits 0" 0 $status
check "--no-cd leaves cwd alone" $start (path resolve $PWD)
check "--no-cd still creates the directory" true (test -d $target; and echo true; or echo false)
check "--no-cd still git inits" true (test -d $target/.git; and echo true; or echo false)
rm -rf $base

section "mkrep: --no-git"

set -l base (_mkrep_sandbox)
set -l target $base/repo
mkrep --no-git $target >/dev/null
check "--no-git exits 0" 0 $status
check "--no-git skips git init" false (test -d $target/.git; and echo true; or echo false)
cd $start
rm -rf $base

section "mkrep: --no-mkdir"

set -l base (_mkrep_sandbox)
set -l target $base/does-not-exist
mkrep --no-mkdir $target >/dev/null 2>/tmp/mkrep-test-err
check "--no-mkdir on missing dir exits 1" 1 $status
check "--no-mkdir does not create the directory" false (test -d $target; and echo true; or echo false)
rm -f /tmp/mkrep-test-err
rm -rf $base

section "mkrep: --strict"

set -l base (_mkrep_sandbox)
set -l target $base/repo
mkdir -p $target
echo sentinel >$target/keep.txt
mkrep --strict $target >/dev/null 2>/tmp/mkrep-test-err
check "--strict on existing dir exits 1" 1 $status
check "--strict leaves the directory untouched" true (test -f $target/keep.txt; and echo true; or echo false)
check "--strict never git inits" false (test -d $target/.git; and echo true; or echo false)
rm -f /tmp/mkrep-test-err
cd $start
rm -rf $base

section "mkrep: --clean"

set -l base (_mkrep_sandbox)
set -l target $base/repo
mkdir -p $target
echo sentinel >$target/keep.txt
mkrep --clean $target >/dev/null
check "--clean exits 0" 0 $status
check "--clean removes prior contents" false (test -f $target/keep.txt; and echo true; or echo false)
check "--clean still leaves a fresh git repo" true (test -d $target/.git; and echo true; or echo false)
cd $start
rm -rf $base

section "mkrep: --clean --strict compose"

set -l base (_mkrep_sandbox)
set -l target $base/repo
mkdir -p $target
echo sentinel >$target/keep.txt
mkrep --clean --strict $target >/dev/null
check "--clean --strict together succeeds" 0 $status
cd $start
rm -rf $base

section "mkrep: negative flag wins over positive"

set -l base (_mkrep_sandbox)
set -l target $base/repo
mkdir -p $target
echo sentinel >$target/keep.txt
mkrep --clean --no-clean $target >/dev/null
check "--clean --no-clean: no-clean wins, contents survive" true (test -f $target/keep.txt; and echo true; or echo false)
cd $start
rm -rf $base

set -l base (_mkrep_sandbox)
set -l target $base/repo
mkrep --cd --no-cd $target >/dev/null
check "--cd --no-cd: no-cd wins, cwd unchanged" $start (path resolve $PWD)
rm -rf $base

section "mkrep: -s/--silent"

set -l base (_mkrep_sandbox)
set -l target $base/repo
set -l out (mkrep -s $target)
check "-s exits 0" 0 $status
check "-s prints nothing" 0 (count $out)
cd $start
rm -rf $base

section "mkrep: --remote (link only)"

set -l base (_mkrep_sandbox)
set -l target $base/repo
mkrep --remote https://example.invalid/me/repo.git $target >/dev/null
check "--remote exits 0" 0 $status
set -l url (git -C $target remote get-url origin)
check "--remote links origin to the given url" https://example.invalid/me/repo.git $url
cd $start
rm -rf $base

# `mkrep .` against an existing checkout, and a plain rerun against the same
# target, both reach `git remote add origin` on a repo that already has one.
# A bare add fails there with "remote origin already exists" and takes the
# whole call down, so linking has to accept the end state it already wanted.
section "mkrep: --remote is idempotent"

set -l base (_mkrep_sandbox)
set -l target $base/repo
mkrep --remote https://example.invalid/me/repo.git $target >/dev/null
mkrep --remote https://example.invalid/me/repo.git $target >/dev/null
check "relinking the same url exits 0" 0 $status
check "relinking leaves one origin" 1 (count (git -C $target remote))
set -l url (git -C $target remote get-url origin)
check "relinking leaves origin untouched" https://example.invalid/me/repo.git $url

# A different url is a different repo. Repointing a checkout the caller did
# not ask about is more likely a mistargeted mkrep than an intended rewrite.
mkrep --remote https://example.invalid/me/other.git $target >/dev/null 2>/tmp/mkrep-test-err
check "relinking a different url exits 1" 1 $status
set -l url (git -C $target remote get-url origin)
check "a refused relink leaves origin alone" https://example.invalid/me/repo.git $url
cd $start
rm -rf $base

section "mkrep: --remote and --new-remote are exclusive"

set -l base (_mkrep_sandbox)
set -l target $base/repo
mkrep --remote https://example.invalid/x.git --new-remote $target >/dev/null 2>/tmp/mkrep-test-err
check "--remote + --new-remote exits 1" 1 $status
check "conflicting remote flags create nothing" false (test -d $target; and echo true; or echo false)
rm -f /tmp/mkrep-test-err
rm -rf $base

section "mkrep: --new-remote requires --git"

set -l base (_mkrep_sandbox)
set -l target $base/repo
mkrep --no-git --new-remote $target >/dev/null 2>/tmp/mkrep-test-err
check "--no-git + --new-remote exits 1" 1 $status
check "rejected combo creates nothing" false (test -d $target; and echo true; or echo false)
rm -f /tmp/mkrep-test-err
rm -rf $base

section "mkrep: --new-remote runs a command template"

set -l base (_mkrep_sandbox)
set -l target $base/repo
mkrep --new-remote='echo {name}/{user} >created.txt' --name demo-repo $target >/dev/null
check "--new-remote exits 0" 0 $status
check "template command ran in the new repo dir" "demo-repo/$USER" (cat $target/created.txt)
cd $start
rm -rf $base

section "mkrep: --new-remote falls back to \$MKREP_REMOTE_CMD"

set -l base (_mkrep_sandbox)
set -l target $base/repo
set -lx MKREP_REMOTE_CMD 'echo {name} >created.txt'
mkrep --new-remote $target >/dev/null
check "env fallback exits 0" 0 $status
check "env fallback template ran" repo (cat $target/created.txt)
cd $start
rm -rf $base

section "mkrep: --server conflicts with --remote/--new-remote"

set -l base (_mkrep_sandbox)
set -l target $base/repo
mkrep --server gitea --remote https://example.invalid/x.git $target >/dev/null 2>/tmp/mkrep-test-err
check "--server + --remote exits 1" 1 $status
mkrep --server gitea --new-remote $target >/dev/null 2>/tmp/mkrep-test-err
check "--server + --new-remote exits 1" 1 $status
check "conflicting server flags create nothing" false (test -d $target; and echo true; or echo false)
rm -f /tmp/mkrep-test-err
rm -rf $base

section "mkrep: --check-existing conflicts with --remote/--new-remote"

set -l base (_mkrep_sandbox)
set -l target $base/repo
mkrep --check-existing --remote https://example.invalid/x.git $target >/dev/null 2>/tmp/mkrep-test-err
check "--check-existing + --remote exits 1" 1 $status
rm -f /tmp/mkrep-test-err
rm -rf $base

section "mkrep: --check-existing needs a resolved server"

begin
    # Shadow to empty rather than erase: these are real exported vars in
    # this dev environment (GITEA_URL et al.), and mkrep treats an empty
    # value the same as unset, so this gives a clean slate without
    # touching the actual global.
    set -lx GIT_SERVER ''
    set -lx GITEA_URL ''
    set -lx GITEA_HOST ''
    set -lx GITLAB_URL ''
    set -lx GITLAB_HOST ''
    set -l base (_mkrep_sandbox)
    set -l target $base/repo
    mkrep --check-existing $target >/dev/null 2>/tmp/mkrep-test-err
    check "--check-existing with no server exits 1" 1 $status
    check "unresolved --check-existing creates nothing" false (test -d $target; and echo true; or echo false)
    rm -f /tmp/mkrep-test-err
    rm -rf $base
end

section "mkrep: --server requires --git"

set -l base (_mkrep_sandbox)
set -l target $base/repo
mkrep --no-git --server gitea $target >/dev/null 2>/tmp/mkrep-test-err
check "--no-git + --server exits 1" 1 $status
rm -f /tmp/mkrep-test-err
rm -rf $base

section "mkrep: --server rejects an unknown type"

set -l base (_mkrep_sandbox)
set -l target $base/repo
mkrep --server bitbucket $target >/dev/null 2>/tmp/mkrep-test-err
check "unknown --server type exits 1" 1 $status
rm -f /tmp/mkrep-test-err
rm -rf $base

# The rest of this section stub gh/glab/tea so no real network/CLI auth is
# needed: a fake binary on $PATH decides whether the "repo" is reported as
# already existing, and $MKREP_REMOTE_CMD (which --server honors exactly
# like --new-remote) stands in for the real create command.
set -g stub_bin (mktemp -d)

function _mkrep_stub_tool --argument-names name exit_code
    printf '#!/bin/sh\nexit %s\n' $exit_code >$stub_bin/$name
    chmod +x $stub_bin/$name
end

section "mkrep: --server's default gitea template survives an empty (commit-less) repo"

begin
    # Regression: mkrep only ever runs `git init`, so a freshly created
    # repo has no commits yet. The default template's final push must not
    # error on that unborn HEAD once `tea repos create` and `git remote
    # add` (both real, local-only) have already succeeded.
    printf '#!/bin/sh\ncase "$2" in\n  create) exit 0 ;;\n  *) exit 1 ;;\nesac\n' >$stub_bin/tea
    chmod +x $stub_bin/tea
    set -l base (_mkrep_sandbox)
    set -l target $base/repo
    set -lx PATH $stub_bin $PATH
    set -lx GITEA_URL https://gitea.example.invalid
    set -lx MKREP_REMOTE_CMD ''
    mkrep --server gitea $target >/dev/null
    check "default template exits 0 with no commits yet" 0 $status
    set -l url (git -C $target remote get-url origin)
    check "default template still linked the new remote" "https://gitea.example.invalid/$USER/repo.git" $url
    cd $start
    rm -rf $base
end

section "mkrep: --server auto-creates when the repo does not exist"

begin
    _mkrep_stub_tool tea 1
    set -l base (_mkrep_sandbox)
    set -l target $base/repo
    set -lx PATH $stub_bin $PATH
    set -lx GITEA_URL https://gitea.example.invalid
    set -lx MKREP_REMOTE_CMD 'echo {server}/{user}/{name} >created.txt'
    mkrep --server gitea $target >/dev/null
    check "--server (repo absent) exits 0" 0 $status
    check "--server ran the create template" "https://gitea.example.invalid/$USER/repo" (cat $target/created.txt)
    cd $start
    rm -rf $base
end

section "mkrep: --server links instead of creating when the repo exists"

begin
    _mkrep_stub_tool tea 0
    set -l base (_mkrep_sandbox)
    set -l target $base/repo
    set -lx PATH $stub_bin $PATH
    set -lx GITEA_URL https://gitea.example.invalid
    set -lx MKREP_REMOTE_CMD 'echo should-not-run >created.txt'
    mkrep --server gitea $target >/dev/null
    check "--server (repo present) exits 0" 0 $status
    check "--server did not run the create template" false (test -f $target/created.txt; and echo true; or echo false)
    set -l url (git -C $target remote get-url origin)
    check "--server linked the existing repo's url" "https://gitea.example.invalid/$USER/repo.git" $url
    cd $start
    rm -rf $base
end

section "mkrep: \$GITEA_HOST gets https:// prepended, \$GITEA_URL wins over it"

begin
    _mkrep_stub_tool tea 1
    set -l base (_mkrep_sandbox)
    set -l target $base/repo
    set -lx PATH $stub_bin $PATH
    set -lx GITEA_URL ''
    set -lx GITEA_HOST gitea.example.invalid
    set -lx MKREP_REMOTE_CMD 'echo {server} >created.txt'
    mkrep --server gitea $target >/dev/null
    check "bare \$GITEA_HOST exits 0" 0 $status
    check "bare \$GITEA_HOST gets https:// prepended" https://gitea.example.invalid (cat $target/created.txt)
    cd $start
    rm -rf $base
end

begin
    _mkrep_stub_tool tea 1
    set -l base (_mkrep_sandbox)
    set -l target $base/repo
    set -lx PATH $stub_bin $PATH
    set -lx GITEA_HOST wrong.example.invalid
    set -lx GITEA_URL https://right.example.invalid
    set -lx MKREP_REMOTE_CMD 'echo {server} >created.txt'
    mkrep --server gitea $target >/dev/null
    check "\$GITEA_URL wins over \$GITEA_HOST exits 0" 0 $status
    check "\$GITEA_URL wins over \$GITEA_HOST, used as-is" https://right.example.invalid (cat $target/created.txt)
    cd $start
    rm -rf $base
end

section "mkrep: \$GITEA_URL alone (no \$GIT_SERVER) does not trigger anything"

begin
    set -l base (_mkrep_sandbox)
    set -l target $base/repo
    set -lx GITEA_URL https://gitea.example.invalid
    mkrep $target >/dev/null
    check "bare \$GITEA_URL exits 0" 0 $status
    check "bare \$GITEA_URL creates no remote" 0 (count (git -C $target remote))
    cd $start
    rm -rf $base
end

section "mkrep: \$GIT_SERVER + \$GITEA_URL together trigger the auto-create flow"

begin
    _mkrep_stub_tool tea 1
    set -l base (_mkrep_sandbox)
    set -l target $base/repo
    set -lx PATH $stub_bin $PATH
    set -lx GIT_SERVER gitea
    set -lx GITEA_URL https://gitea.example.invalid
    set -lx MKREP_REMOTE_CMD 'echo {name} >created.txt'
    mkrep --yes $target >/dev/null
    check "--yes on the \$GIT_SERVER path exits 0" 0 $status
    check "\$GIT_SERVER picked gitea" repo (cat $target/created.txt)
    cd $start
    rm -rf $base
end

# The $GIT_SERVER path creates a repo on a live forge off nothing but an
# exported variable, so it confirms first. These cases run non-interactively
# (run-tests.fish uses `fish --no-config`), which is itself one of the
# behaviors under test: with no tty to ask, creation is skipped rather than
# assumed. The interactive y/N read is not covered here -- that needs a PTY,
# and the answer parsing it guards is a single `string match`.
section "mkrep: an implicit \$GIT_SERVER remote-create is not silently performed"

begin
    _mkrep_stub_tool tea 1
    set -l base (_mkrep_sandbox)
    set -l target $base/repo
    set -lx PATH $stub_bin $PATH
    set -lx GIT_SERVER gitea
    set -lx GITEA_URL https://gitea.example.invalid
    set -lx MKREP_REMOTE_CMD 'echo {name} >created.txt'
    mkrep $target >/dev/null 2>$base/err
    check "unconfirmed \$GIT_SERVER create exits 0" 0 $status
    check "unconfirmed \$GIT_SERVER create ran no command" false (test -e $target/created.txt; and echo true; or echo false)
    check "unconfirmed \$GIT_SERVER create added no remote" 0 (count (git -C $target remote))
    check "the local repo is still set up" true (test -d $target/.git; and echo true; or echo false)
    check "the skip is reported on stderr" true (string match -q '*Skipped creating*' -- (cat $base/err); and echo true; or echo false)
    check "the note names --yes" true (string match -q '*--yes*' -- (cat $base/err); and echo true; or echo false)
    cd $start
    rm -rf $base
end

section "mkrep: an explicit --server never prompts"

begin
    _mkrep_stub_tool tea 1
    set -l base (_mkrep_sandbox)
    set -l target $base/repo
    set -lx PATH $stub_bin $PATH
    set -lx GITEA_URL https://gitea.example.invalid
    set -lx MKREP_REMOTE_CMD 'echo {name} >created.txt'
    mkrep --server gitea $target >/dev/null 2>$base/err
    check "--server exits 0 with no tty" 0 $status
    check "--server created without confirming" repo (cat $target/created.txt)
    check "--server printed no skip note" false (string match -q '*Skipped creating*' -- (cat $base/err); and echo true; or echo false)
    cd $start
    rm -rf $base
end

section "mkrep: an explicit --remote overrides \$GIT_SERVER/\$GITEA_URL"

begin
    set -l base (_mkrep_sandbox)
    set -l target $base/repo
    set -lx GIT_SERVER gitea
    set -lx GITEA_URL https://gitea.example.invalid
    mkrep --remote https://example.invalid/me/repo.git $target >/dev/null
    check "--remote over env exits 0" 0 $status
    set -l url (git -C $target remote get-url origin)
    check "--remote wins over \$GIT_SERVER/\$GITEA_URL" https://example.invalid/me/repo.git $url
    cd $start
    rm -rf $base
end

section "mkrep: --check-existing reports without creating anything"

begin
    _mkrep_stub_tool tea 0
    set -l base (_mkrep_sandbox)
    set -l target $base/repo
    set -lx PATH $stub_bin $PATH
    set -l out (mkrep --server gitea --check-existing $target)
    check "--check-existing exits 0" 0 $status
    check "--check-existing creates the directory (mkrep's other defaults still run)" true (test -d $target; and echo true; or echo false)
    check "--check-existing adds no remote" 0 (count (git -C $target remote))
    cd $start
    rm -rf $base
end

rm -rf $stub_bin

section "mkrep: --help"

set -l base (_mkrep_sandbox)
set -l out (mkrep --help)
check "--help exits 0" 0 $status
check "--help prints usage" true (string match -q -- '*Usage:*' $out; and echo true; or echo false)
check "--help creates nothing" false (test -d $base/repo; and echo true; or echo false)
rm -rf $base

cd $start
report
