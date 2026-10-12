#!/usr/bin/env fish
# Copyright (C) 2026 Rootiest
# SPDX-License-Identifier: AGPL-3.0-or-later
#
# Unit coverage for mkrep's private helpers, called directly rather than
# through mkrep: _mkrep_say, _mkrep_remote_url, _mkrep_default_remote_cmd,
# _mkrep_expand_template, _mkrep_repo_exists and _mkrep_add_origin.
# test-mkrep.fish drives the same code through mkrep's flag matrix; this
# suite pins each helper's own contract (exit codes, quoting, idempotence)
# so a regression names the helper that broke instead of a mkrep flow.
#
# Runs isolated (no `# MODE:` marker): it cds into throwaway repos and puts
# stub forge CLIs first on $PATH. Nothing here may reach a real forge, so
# every case that runs a gh/glab/tea command does it with $PATH narrowed to
# a mktemp -d directory of stubs that only log their argv -- the real
# binaries (and curl) are not reachable at all while those cases run.

source (realpath (dirname (status filename)))/lib.fish
set -p fish_function_path $repo_root/functions

# Same neutralization as test-mkrep.fish: this repo doubles as a live
# ~/.config/fish where these are exported for day-to-day use. None of the
# helpers read them directly, but a template expanded and evaled here must
# never pick up a real server from the environment.
set -gx GIT_SERVER ''
set -gx GITEA_URL ''
set -gx GITEA_HOST ''
set -gx GITLAB_URL ''
set -gx GITLAB_HOST ''

set -gx GIT_AUTHOR_NAME t
set -gx GIT_AUTHOR_EMAIL t@t
set -gx GIT_COMMITTER_NAME t
set -gx GIT_COMMITTER_EMAIL t@t
set -gx GIT_CONFIG_COUNT 3
set -gx GIT_CONFIG_KEY_0 init.defaultBranch
set -gx GIT_CONFIG_VALUE_0 main
set -gx GIT_CONFIG_KEY_1 commit.gpgsign
set -gx GIT_CONFIG_VALUE_1 false
set -gx GIT_CONFIG_KEY_2 core.hooksPath
set -gx GIT_CONFIG_VALUE_2 /dev/null

set -g start $PWD
set -g sandbox (path resolve (mktemp -d))

# Stub forge CLIs: each logs one line per argument to $STUB_LOG, prefixed
# by its own name, and exits $STUB_RC (default 0). /bin/sh builtins only,
# so a $PATH holding nothing but this directory still runs them.
set -g stubs $sandbox/stubs
mkdir -p $stubs
for tool in gh glab tea curl
    printf '%s\n' '#!/bin/sh' \
        "for a in \"\$@\"; do printf '%s %s\\n' $tool \"\$a\" >>\"\$STUB_LOG\"; done" \
        'exit ${STUB_RC:-0}' >$stubs/$tool
    chmod +x $stubs/$tool
end
set -gx STUB_LOG $sandbox/stub.log

function reset_log
    rm -f $STUB_LOG
    touch $STUB_LOG
end

#   ──────────────────────────── _mkrep_say ────────────────────────────

section _mkrep_say

check "silent=0 prints the message" hello (_mkrep_say 0 hello)
check "silent=0 exits 0" 0 (_mkrep_say 0 hello >/dev/null; echo $status)
check "silent=1 prints nothing" "" (_mkrep_say 1 hello | string collect)
check "silent=1 exits 0" 0 (_mkrep_say 1 hello; echo $status)
check "escapes render (echo -e)" (printf 'a\tb') (_mkrep_say 0 'a\tb')
# Only an exact 1 silences: mkrep passes 0/1, and anything else must not
# swallow output by accident.
check "silent=yes still prints" hi (_mkrep_say yes hi)

#   ────────────────────────── _mkrep_remote_url ───────────────────────

section _mkrep_remote_url

check "github ignores the server url" https://github.com/me/proj.git (_mkrep_remote_url github me proj https://ignored.example)
check "github with no url still builds" https://github.com/me/proj.git (_mkrep_remote_url github me proj)
check "gitea joins the server url" https://git.example/me/proj.git (_mkrep_remote_url gitea me proj https://git.example)
check "gitlab joins the server url" https://gl.example/grp/proj.git (_mkrep_remote_url gitlab grp proj https://gl.example)

set -l out (_mkrep_remote_url gitea me proj)
check "gitea with no url exits 1" 1 $status
check "gitea with no url prints nothing" "" "$out"
set -l out (_mkrep_remote_url gitlab me proj '')
check "gitlab with empty url exits 1" 1 $status
check "gitlab with empty url prints nothing" "" "$out"
set -l out (_mkrep_remote_url bitbucket me proj https://x)
check "unknown type exits 1" 1 $status
check "unknown type prints nothing" "" "$out"

#   ────────────────────── _mkrep_default_remote_cmd ───────────────────

section _mkrep_default_remote_cmd

for t in github gitlab gitea
    set -l tpl (_mkrep_default_remote_cmd $t)
    check "$t: exits 0" 0 $status
    check "$t: exactly one template line" 1 (count $tpl)
    check "$t: template uses {name}" true (string match -q '*{name}*' -- "$tpl"; and echo true; or echo false)
end
check "github template drives gh" true (string match -q 'gh repo create {name} *' -- (_mkrep_default_remote_cmd github); and echo true; or echo false)
check "gitlab template drives glab" true (string match -q 'glab repo create {name} *' -- (_mkrep_default_remote_cmd gitlab); and echo true; or echo false)
check "gitea template drives tea" true (string match -q 'tea repos create --name {name} *' -- (_mkrep_default_remote_cmd gitea); and echo true; or echo false)
for t in gitlab gitea
    check "$t: push is guarded on HEAD resolving" true (string match -q '*if git rev-parse --verify -q HEAD*git push -u origin HEAD; end' -- (_mkrep_default_remote_cmd $t); and echo true; or echo false)
    check "$t: origin uses {server}/{user}/{name}.git" true (string match -q '*git remote add origin {server}/{user}/{name}.git*' -- (_mkrep_default_remote_cmd $t); and echo true; or echo false)
end
set -l out (_mkrep_default_remote_cmd svn)
check "unknown type exits 1" 1 $status
check "unknown type prints nothing" "" "$out"
set -l out (_mkrep_default_remote_cmd)
check "no type exits 1" 1 $status

#   ─────────────────────── _mkrep_expand_template ─────────────────────

section "_mkrep_expand_template: substitution"

check "all three placeholders" "x proj me srv" (_mkrep_expand_template 'x {name} {user} {server}' proj me srv)
check "repeated placeholders all replaced" "proj-proj me/me" (_mkrep_expand_template '{name}-{name} {user}/{user}' proj me)
check "{server} left as written when empty" "a {server}/me" (_mkrep_expand_template 'a {server}/{user}' n me '')
check "{server} left as written when omitted" "{server}" (_mkrep_expand_template '{server}' n me)
check "no placeholders passes through" "echo plain" (_mkrep_expand_template 'echo plain' n u s)
check "exits 0" 0 (_mkrep_expand_template '{name}' n u >/dev/null; echo $status)

# Single pass: a value that spells another placeholder is not re-expanded.
check "name spelling {user} stays literal" (string escape -- '{user}')"/me" (_mkrep_expand_template '{name}/{user}' '{user}' me)
check "user spelling {server} stays literal" (string escape -- '{server}')" S" (_mkrep_expand_template '{user} {server}' n '{server}' S)

section "_mkrep_expand_template: injection-safe through eval"

# The expanded command is eval'd by mkrep. Run it the same way here, with a
# recorder in place of the forge CLI, and check each hostile value arrives
# as exactly one literal argument and nothing in it executes.
set -l inj $sandbox/inj
mkdir -p $inj
function __rec
    printf '%s\n' $argv >>$STUB_LOG
end
set -l i 0
for hostile in 'a;touch '$inj/pwned1 'b$(touch '$inj/pwned2')' 'c`touch '$inj/pwned3'`' "d'e\"f" 'g h' 'i|touch '$inj/pwned4
    set i (math $i + 1)
    reset_log
    eval (_mkrep_expand_template '__rec {name}' $hostile me)
    check "hostile {name} #$i arrives as one literal arg" $hostile (string collect <$STUB_LOG)
end
reset_log
eval (_mkrep_expand_template '__rec {user} {server}' n 'u;touch '$inj/pwned5 'https://s/$(touch '$inj/pwned6')')
check "user and server values arrive literal" "u;touch $inj/pwned5|https://s/\$(touch $inj/pwned6)" (string join '|' <$STUB_LOG)
check "nothing in a hostile value executed" "" (ls -A $inj | string collect)
functions -e __rec

#   ───────────────────── _mkrep_default_remote_cmd: run ───────────────

section "default templates, expanded and run against stub CLIs"

# A file-path "server" holding a real bare repo stands in for the forge, so
# the push half of the gitea/gitlab templates runs for real while the
# create half hits the logging stub. $PATH is narrowed to the stubs plus a
# directory holding only a git symlink, so no real forge CLI can be found.
set -l gitdir $sandbox/gitbin
mkdir -p $gitdir
ln -s (command -s git) $gitdir/git
set -l server $sandbox/server
mkdir -p $server/me
git init -q --bare $server/me/proj.git

for t in gitea gitlab
    set -l work $sandbox/work-$t
    mkdir -p $work
    git -C $work init -q
    cd $work
    reset_log
    begin
        set -lx PATH $stubs $gitdir
        eval (_mkrep_expand_template (_mkrep_default_remote_cmd $t) proj me $server)
    end
    set -l rc $status
    cd $start
    check "$t, unborn HEAD: exits 0 (push skipped, not failed)" 0 $rc
    check "$t, unborn HEAD: origin linked" $server/me/proj.git (git -C $work remote get-url origin)
    set -l want "tea repos|tea create|tea --name|tea proj|tea --private"
    test $t = gitlab; and set want "glab repo|glab create|glab proj|glab --private|glab --skipGitInit"
    check "$t, unborn HEAD: create stub argv" $want (string join '|' <$STUB_LOG)
    check "$t, unborn HEAD: bare repo got nothing" "" (git -C $server/me/proj.git for-each-ref | string collect)
end

# With a commit, the guarded push runs and must actually land.
set -l work $sandbox/work-push
mkdir -p $work
git -C $work init -q
echo x >$work/f
git -C $work add f
git -C $work commit -qm init
cd $work
reset_log
begin
    set -lx PATH $stubs $gitdir
    eval (_mkrep_expand_template (_mkrep_default_remote_cmd gitea) proj me $server) >/dev/null 2>&1
end
set -l rc $status
cd $start
check "gitea, with a commit: exits 0" 0 $rc
check "gitea, with a commit: push landed" (git -C $work rev-parse HEAD) (git -C $server/me/proj.git rev-parse main 2>/dev/null)

# A real push failure still propagates: point {server} at a path with no
# repo behind it.
set -l work $sandbox/work-pushfail
mkdir -p $work
git -C $work init -q
echo x >$work/f
git -C $work add f
git -C $work commit -qm init
cd $work
begin
    set -lx PATH $stubs $gitdir
    eval (_mkrep_expand_template (_mkrep_default_remote_cmd gitea) proj me $sandbox/nowhere) >/dev/null 2>&1
end
set -l rc $status
cd $start
check "gitea, push to a missing repo: failure propagates" true (test $rc -ne 0; and echo true; or echo false)

# A failing create stub stops the && chain before origin is touched.
set -l work $sandbox/work-createfail
mkdir -p $work
git -C $work init -q
cd $work
begin
    set -lx PATH $stubs $gitdir
    set -lx STUB_RC 1
    eval (_mkrep_expand_template (_mkrep_default_remote_cmd gitea) proj me $server) >/dev/null 2>&1
end
set -l rc $status
cd $start
check "gitea, create fails: exits non-zero" true (test $rc -ne 0; and echo true; or echo false)
check "gitea, create fails: origin never added" "" (git -C $work remote 2>/dev/null | string collect)

# github: the whole job is one gh call; check its argv.
set -l work $sandbox/work-gh
mkdir -p $work
git -C $work init -q
cd $work
reset_log
begin
    set -lx PATH $stubs $gitdir
    eval (_mkrep_expand_template (_mkrep_default_remote_cmd github) 'my proj' me)
end
set -l rc $status
cd $start
check "github: exits 0" 0 $rc
check "github: gh argv" "gh repo|gh create|gh my proj|gh --private|gh --source=.|gh --remote=origin|gh --push" (string join '|' <$STUB_LOG)

#   ───────────────────────── _mkrep_repo_exists ───────────────────────

section _mkrep_repo_exists

for pair in github:gh gitlab:glab gitea:tea
    set -l t (string split -f1 : $pair)
    set -l tool (string split -f2 : $pair)
    reset_log
    begin
        set -lx PATH $stubs
        set -lx STUB_RC 0
        _mkrep_repo_exists $t me 'my repo'
    end
    check "$t: tool says yes -> 0" 0 $status
    set -l want "$tool repo|$tool view|$tool me/my repo"
    test $t = gitea; and set want "tea repos|tea me/my repo"
    check "$t: lookup argv (user/name is one arg)" $want (string join '|' <$STUB_LOG)

    begin
        set -lx PATH $stubs
        set -lx STUB_RC 1
        _mkrep_repo_exists $t me proj
    end
    check "$t: tool says no -> 1" 1 $status

    # Any non-zero from the tool is "does not exist", not passed through.
    begin
        set -lx PATH $stubs
        set -lx STUB_RC 4
        _mkrep_repo_exists $t me proj
    end
    check "$t: tool exit 4 -> non-zero" true (test $status -ne 0; and echo true; or echo false)

    # Tool missing entirely: an empty $PATH.
    begin
        set -lx PATH $sandbox/empty
        _mkrep_repo_exists $t me proj
    end
    check "$t: tool missing -> 1" 1 $status
end
reset_log
begin
    set -lx PATH $stubs
    _mkrep_repo_exists bitbucket me proj
end
check "unknown type -> 1" 1 $status
check "unknown type calls no tool" "" (string collect <$STUB_LOG)
check "stub output never leaks to stdout" "" (begin; set -lx PATH $stubs; _mkrep_repo_exists github me proj; end | string collect)

#   ───────────────────────── _mkrep_add_origin ────────────────────────

section _mkrep_add_origin

set -l repo $sandbox/origin-repo
mkdir -p $repo
git -C $repo init -q
cd $repo
set -l out (_mkrep_add_origin 0 https://a.example/me/r.git)
set -l rc $status
check "no origin: exits 0" 0 $rc
check "no origin: origin added" https://a.example/me/r.git (git remote get-url origin)
check "no origin: reports the link" true (string match -q '*Linked remote*https://a.example/me/r.git*' -- "$out"; and echo true; or echo false)

set -l out (_mkrep_add_origin 0 https://a.example/me/r.git)
check "same url again: exits 0 (idempotent)" 0 $status
check "same url again: says already linked" true (string match -q '*already points at*' -- "$out"; and echo true; or echo false)
check "same url again: still one origin url" 1 (count (git remote get-url --all origin))

set -l out (_mkrep_add_origin 1 https://a.example/me/r.git)
check "same url, silent: exits 0" 0 $status
check "same url, silent: prints nothing" "" "$out"

set -l err (_mkrep_add_origin 0 https://b.example/me/other.git 2>&1 >/dev/null)
check "different url: exits 1" 1 $status
check "different url: error names both urls" true (string match -q '*a.example/me/r.git*b.example/me/other.git*' -- "$err"; and echo true; or echo false)
check "different url: suggests set-url" true (string match -q '*git remote set-url origin*' -- "$err"; and echo true; or echo false)
check "different url: origin not repointed" https://a.example/me/r.git (git remote get-url origin)
check "different url: nothing on stdout" "" (_mkrep_add_origin 0 https://b.example/x.git 2>/dev/null | string collect)
cd $start

set -l repo2 $sandbox/origin-silent
mkdir -p $repo2
git -C $repo2 init -q
cd $repo2
set -l out (_mkrep_add_origin 1 'https://a.example/me/odd;name.git')
check "silent add: exits 0" 0 $status
check "silent add: prints nothing" "" "$out"
check "url with ; is stored literally" 'https://a.example/me/odd;name.git' (git remote get-url origin)
cd $start

# Not a repo: git remote add fails, and the failure is surfaced.
set -l norepo $sandbox/not-a-repo
mkdir -p $norepo
cd $norepo
set -l err (begin; set -lx GIT_CEILING_DIRECTORIES $sandbox; _mkrep_add_origin 0 https://a.example/x.git; end 2>&1 >/dev/null)
set -l rc $status
cd $start
check "not a repo: exits 1" 1 $rc
check "not a repo: reports the failure" true (string match -q '*Failed to add remote*' -- "$err"; and echo true; or echo false)

check "cwd restored" $start $PWD

rm -rf $sandbox
report
