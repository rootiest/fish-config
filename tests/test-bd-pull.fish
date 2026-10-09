#!/usr/bin/env fish
# Copyright (C) 2026 Rootiest
# SPDX-License-Identifier: AGPL-3.0-or-later
#
# Regression coverage for #226: bd-pull.
#   - the title-update payload is built by jq (quotes/backslashes stay valid)
#   - the issues endpoint is paginated and asks for type=issues&state=open
#   - pull requests and closed issues are never linked
#   - an HTTP error (401) is reported on stderr and nothing is mutated
#   - the token never appears on a command line (curl config file, mode 600)
#   - only .beads/issues.jsonl is committed; already-staged files are left
#     alone, and nothing is pushed unless --push is given
#   - an undeterminable Bead ID skips the issue instead of writing "[ ] title"
#   - missing curl/jq/bd/git and bad usage are reported on stderr
#
# Runs isolated (no `# MODE:` marker): its own `fish --no-config` process.
# Everything is hermetic: curl and bd are stubs that read canned files, the
# stub curl never opens a socket, git runs against throwaway repos with the
# user's git config disabled (no signing, no hooks), and the only "remote" is
# a local bare repository.

source (realpath (dirname (status filename)))/lib.fish
set -p fish_function_path $repo_root/functions

set -gx TERM xterm-256color

# Hermetic git: never read the real ~/.gitconfig, never sign, never prompt.
set -gx GIT_CONFIG_GLOBAL /dev/null
set -gx GIT_CONFIG_NOSYSTEM 1
set -gx GIT_CONFIG_COUNT 2
set -gx GIT_CONFIG_KEY_0 commit.gpgsign
set -gx GIT_CONFIG_VALUE_0 false
set -gx GIT_CONFIG_KEY_1 core.hooksPath
set -gx GIT_CONFIG_VALUE_1 /dev/null
set -gx GIT_AUTHOR_NAME t
set -gx GIT_AUTHOR_EMAIL t@t
set -gx GIT_COMMITTER_NAME t
set -gx GIT_COMMITTER_EMAIL t@t
set -gx GIT_TERMINAL_PROMPT 0

# An unresolvable host, and a token the argv assertions can search for.
set -gx GITEA_URL https://gitea.invalid
set -gx GITEA_TOKEN tok-SECRET123

set -g TMPDIRS
set -g START $PWD

function cleanup
    builtin cd $START
    for d in $TMPDIRS
        test -n "$d"; and command rm -rf $d
    end
end

# ── stubs ────────────────────────────────────────────────────────────────────
set -l stubsrc (mktemp -d)
set -ga TMPDIRS $stubsrc

# curl: logs argv, the curl config it was handed (-K), the mode of that file,
# and the --data-binary payload; serves $BDP_DIR/page-N.json for the page=N
# in the URL (an empty list when absent); fails like `curl -f` when
# $BDP_HTTP_STATUS is set.
printf '%s\n' \
    '#!/bin/sh' \
    'printf "%s\n" "$*" >> "$BDP_DIR/argv.log"' \
    'cfg=; data=; url=; method=GET' \
    'while [ $# -gt 0 ]; do' \
    '  case "$1" in' \
    '    -K) cfg=$2; shift ;;' \
    '    --data-binary) data=${2#@}; shift ;;' \
    '    -X) method=$2; shift ;;' \
    '    --max-time|-H) shift ;;' \
    '    -*) ;;' \
    '    *) url=$1 ;;' \
    '  esac' \
    '  shift' \
    done \
    'if [ -n "$cfg" ]; then' \
    '  cat "$cfg" >> "$BDP_DIR/cfg.log"' \
    '  stat -c %a "$cfg" >> "$BDP_DIR/mode.log"' \
    fi \
    'if [ -n "$data" ]; then cat "$data" >> "$BDP_DIR/payload.log"; fi' \
    'if [ -n "$BDP_HTTP_STATUS" ]; then' \
    '  echo "curl: (22) The requested URL returned error: $BDP_HTTP_STATUS" >&2' \
    '  exit 22' \
    fi \
    'if [ "$method" = PATCH ]; then' \
    '  echo "$method $url" >> "$BDP_DIR/patch.log"' \
    '  echo "{}"' \
    '  exit 0' \
    fi \
    'echo "$url" >> "$BDP_DIR/urls.log"' \
    'page=${url##*page=}' \
    'if [ -f "$BDP_DIR/page-$page.json" ]; then cat "$BDP_DIR/page-$page.json"; else echo "[]"; fi' \
    'exit 0' >$stubsrc/curl

# bd: `create` logs its arguments, numbers beads bd-1, bd-2, ..., prints the
# id and appends it to .beads/issues.jsonl. With $BDP_BD_NOID it prints no id
# and writes nothing, so bd-pull cannot learn the id at all.
printf '%s\n' \
    '#!/bin/sh' \
    'case "$1" in' \
    '  create)' \
    '    printf "%s\n" "$*" >> "$BDP_DIR/bd.log"' \
    '    if [ -n "$BDP_BD_NOID" ]; then echo "created"; exit 0; fi' \
    '    n=$(cat "$BDP_DIR/bd.count" 2>/dev/null || echo 0)' \
    '    n=$((n + 1))' \
    '    echo "$n" > "$BDP_DIR/bd.count"' \
    '    echo "{\"id\":\"bd-$n\"}" >> .beads/issues.jsonl' \
    '    echo "Created issue bd-$n"' \
    '    ;;' \
    '  sync) echo sync >> "$BDP_DIR/bd.log" ;;' \
    esac \
    'exit 0' >$stubsrc/bd
chmod +x $stubsrc/curl $stubsrc/bd

# A PATH directory holding the stubs plus the real tools bd-pull needs.
# $argv[1] names one tool to leave out (missing-tool cases).
function _bdp_bin --argument-names skip
    set -l bin (mktemp -d)
    set -ga TMPDIRS $bin
    for t in sh cat sed stat mktemp touch chmod tail head rm tr dirname basename wc ls mkdir grep jq git
        test "$t" = "$skip"; and continue
        command ln -s (command -s $t) $bin/$t
    end
    for t in curl bd
        test "$t" = "$skip"; and continue
        command ln -s $stubsrc/$t $bin/$t
    end
    echo $bin
end

set -g FULL_BIN (_bdp_bin none)

# ── fixtures ─────────────────────────────────────────────────────────────────
set -g HOSTILE 'He said "hi" \ back'

# A fresh repo (with a local bare "origin") and a fresh stub state dir.
function _bdp_setup
    set -g STATE (mktemp -d)
    set -g REPO (mktemp -d)
    set -g BARE (mktemp -d)
    set -ga TMPDIRS $STATE $REPO $BARE
    set -gx BDP_DIR $STATE
    set -e BDP_HTTP_STATUS
    set -e BDP_BD_NOID

    git init -q --bare $BARE
    git init -q -b main $REPO
    command mkdir -p $REPO/.beads
    command touch $REPO/.beads/issues.jsonl
    echo keep >$REPO/keep.txt
    git -C $REPO add .
    git -C $REPO commit -q -m init
    git -C $REPO remote add origin $BARE
    git -C $REPO push -q -u origin main
    set -g BASE_SHA (git -C $REPO rev-parse HEAD)

    # Page 1: a plain issue, an already linked one, and a pull request.
    # Page 2 (shorter, so the last): a closed issue and a hostile title.
    jq -nc '[
        {number: 1, state: "open", title: "Plain issue one"},
        {number: 2, state: "open", title: "[bd-7] Already linked"},
        {number: 3, state: "open", title: "A pull request", pull_request: {merged: false}}
    ]' >$STATE/page-1.json
    jq -nc --arg t "$HOSTILE" '[
        {number: 4, state: "closed", title: "Closed issue"},
        {number: 5, state: "open", title: $t}
    ]' >$STATE/page-2.json
end

# Run bd-pull in $REPO with the given PATH dir; stdout/stderr land in
# $STATE/out and $STATE/err. Returns bd-pull's status.
function _bdp_run --argument-names bin
    # PATH is swapped globally, not with `set -lx`: bd-pull is a function, and
    # a block-local variable here would not be visible inside its scope.
    set -l saved_path $PATH
    set -gx PATH $bin
    builtin cd $REPO
    bd-pull $argv[2..] >$STATE/out 2>$STATE/err
    set -l code $status
    set -gx PATH $saved_path
    builtin cd $START
    return $code
end

function _has --argument-names file pattern
    if not test -f "$file"
        echo false
        return
    end
    if string match -q -- "*$pattern*" (string collect <$file)
        echo true
    else
        echo false
    end
end

# Line and byte counts via wc (the stubs write newline-terminated lines), so an
# empty or missing file is a plain 0 rather than an empty argument.
function _nlines --argument-names file
    if not test -f "$file"
        echo 0
        return
    end
    string trim -- (wc -l <$file)
end

function _len --argument-names file
    if not test -f "$file"
        echo 0
        return
    end
    string trim -- (wc -c <$file)
end

# ── pagination, exclusion, hostile title, token handling, commit scope ──────
section "bd-pull: happy path (2 pages, PR + closed excluded)"
_bdp_setup
echo staged >$REPO/staged.txt
git -C $REPO add staged.txt

_bdp_run $FULL_BIN rootiest/test
check "exits 0" 0 $status

check "two pages requested (stops on the short page)" 2 (_nlines $STATE/urls.log)
check "asks for type=issues" true (_has $STATE/urls.log 'type=issues')
check "asks for state=open" true (_has $STATE/urls.log 'state=open')
check "asks for an explicit limit" true (_has $STATE/urls.log 'limit=')
check "page 1 requested" true (_has $STATE/urls.log 'page=1')
check "page 2 requested" true (_has $STATE/urls.log 'page=2')
check "no page 3" false (_has $STATE/urls.log 'page=3')

check "two beads created (PR, closed and linked issues skipped)" 2 (count (string match -r '^create .*' -- (string split \n -- (string collect <$STATE/bd.log))))
check "bead for the plain issue" true (_has $STATE/bd.log 'create --title Plain issue one')
check "bead for the hostile title" true (_has $STATE/bd.log 'He said "hi" \\\\ back')
check "no bead for the pull request" false (_has $STATE/bd.log 'A pull request')
check "no bead for the closed issue" false (_has $STATE/bd.log 'Closed issue')
check "no bead for the already linked issue" false (_has $STATE/bd.log 'Already linked')

check "two title updates sent" 2 (_nlines $STATE/patch.log)
check "plain issue #1 patched" true (_has $STATE/patch.log '/issues/1')
check "hostile issue #5 patched" true (_has $STATE/patch.log '/issues/5')
check "PR #3 not patched" false (_has $STATE/patch.log '/issues/3')
check "closed #4 not patched" false (_has $STATE/patch.log '/issues/4')

# Payloads: every line is valid JSON and the hostile title round-trips.
set -l payloads (string split \n -- (string trim -- (string collect <$STATE/payload.log)))
check "payload count" 2 (count $payloads)
check "payload 1 is valid JSON" true (printf '%s\n' $payloads[1] | jq -e . >/dev/null 2>&1; and echo true; or echo false)
check "payload 2 is valid JSON" true (printf '%s\n' $payloads[2] | jq -e . >/dev/null 2>&1; and echo true; or echo false)
check "payload 1 title" "[bd-1] Plain issue one" (printf '%s\n' $payloads[1] | jq -r .title)
check "hostile title round-trips through the payload" "[bd-2] $HOSTILE" (printf '%s\n' $payloads[2] | jq -r .title)
check "payload carries only a title key" '["title"]' (printf '%s\n' $payloads[2] | jq -c 'keys')

section "bd-pull: token stays off the command line"
check "token not in any curl argv" false (_has $STATE/argv.log 'tok-SECRET123')
check "token not in bd argv" false (_has $STATE/bd.log 'tok-SECRET123')
check "token reaches curl via the config file" true (_has $STATE/cfg.log 'Authorization: token tok-SECRET123')
check "config file was mode 600 on every call" 600 (string join '' -- (sort -u $STATE/mode.log))

section "bd-pull: commit scope and push policy (no --push)"
check "HEAD advanced by exactly one commit" 1 (git -C $REPO rev-list --count $BASE_SHA..HEAD)
check "commit subject" "chore: sync local IDs for web issues" (git -C $REPO log -1 --pretty=%s)
check "commit holds only .beads/issues.jsonl" ".beads/issues.jsonl" (git -C $REPO show --name-only --pretty=format: HEAD | string match -r '\S+' | string join ,)
check "unrelated staged file is NOT committed" false (git -C $REPO show --name-only --pretty=format: HEAD | string match -q staged.txt; and echo true; or echo false)
check "unrelated staged file is still staged" staged.txt (git -C $REPO diff --cached --name-only)
check "default run does not push" $BASE_SHA (git -C $BARE rev-parse main)
check "default run says it did not push" true (_has $STATE/out 'Not pushed')
check "no stderr noise on success" 0 (_len $STATE/err)

section "bd-pull: --push"
_bdp_setup
_bdp_run $FULL_BIN --push rootiest/test
check "--push exits 0" 0 $status
set -l local_head (git -C $REPO rev-parse HEAD)
check "--push advances HEAD" false (test "$local_head" = "$BASE_SHA"; and echo true; or echo false)
check "--push pushes to the (local) remote" $local_head (git -C $BARE rev-parse main)

# ── HTTP errors ──────────────────────────────────────────────────────────────
section "bd-pull: HTTP 401 is reported and nothing is mutated"
_bdp_setup
set -gx BDP_HTTP_STATUS 401
_bdp_run $FULL_BIN rootiest/test
check "401 exits 1" 1 $status
check "401 is named on stderr" true (_has $STATE/err '401')
check "stderr points at the token" true (_has $STATE/err 'GITEA_TOKEN')
check "no jq parse noise" false (_has $STATE/err 'parse error')
check "nothing on stdout claims linking" false (_has $STATE/out 'Linked')
check "no bead created" false (test -f $STATE/bd.log; and echo true; or echo false)
check "no title update attempted" false (test -f $STATE/patch.log; and echo true; or echo false)
check "no commit made" $BASE_SHA (git -C $REPO rev-parse HEAD)
check "issues.jsonl untouched" 0 (_len $REPO/.beads/issues.jsonl)
set -e BDP_HTTP_STATUS

section "bd-pull: a non-list response is rejected"
_bdp_setup
echo '{"message":"not a list"}' >$STATE/page-1.json
_bdp_run $FULL_BIN rootiest/test
check "object response exits 1" 1 $status
check "object response is reported" true (_has $STATE/err 'unexpected')
check "object response creates nothing" false (test -f $STATE/bd.log; and echo true; or echo false)

# ── empty / unknown Bead ID ──────────────────────────────────────────────────
section "bd-pull: undeterminable Bead ID skips the issue"
_bdp_setup
echo '[]' >$STATE/page-2.json
set -gx BDP_BD_NOID 1
_bdp_run $FULL_BIN rootiest/test
check "empty-ID run exits 1" 1 $status
check "warning names the issue" true (_has $STATE/err '#1')
check "warning mentions the Bead ID" true (_has $STATE/err 'Bead ID')
check "no title update (never '[ ] title')" false (test -f $STATE/patch.log; and echo true; or echo false)
check "no payload ever built" false (test -f $STATE/payload.log; and echo true; or echo false)
check "no commit" $BASE_SHA (git -C $REPO rev-parse HEAD)
set -e BDP_BD_NOID

# ── missing tools ────────────────────────────────────────────────────────────
section "bd-pull: missing tools"
for tool in curl jq bd git
    _bdp_setup
    set -l bin (_bdp_bin $tool)
    _bdp_run $bin rootiest/test
    check "no $tool: exits 1" 1 $status
    check "no $tool: names the tool on stderr" true (_has $STATE/err "'$tool'")
    check "no $tool: single stderr line" 1 (_nlines $STATE/err)
    check "no $tool: nothing on stdout" 0 (_len $STATE/out)
    check "no $tool: no request made" false (test -f $STATE/argv.log; and echo true; or echo false)
end

# ── usage and environment errors go to stderr ───────────────────────────────
section "bd-pull: usage errors"
_bdp_setup
_bdp_run $FULL_BIN
check "no repo argument: exits 2" 2 $status
check "no repo argument: message on stderr" true (_has $STATE/err 'owner/name')
check "no repo argument: stdout empty" 0 (_len $STATE/out)

_bdp_run $FULL_BIN notarepo
check "malformed repo: exits 2" 2 $status
check "malformed repo: message on stderr" true (_has $STATE/err 'owner/name')
check "malformed repo: stdout empty" 0 (_len $STATE/out)

_bdp_run $FULL_BIN --definitely-not-an-option rootiest/test
check "unknown option: exits 2" 2 $status
check "unknown option: reported on stderr" true (_has $STATE/err 'definitely-not-an-option')

set -gx GITEA_TOKEN ''
_bdp_run $FULL_BIN rootiest/test
check "no token: exits 1" 1 $status
check "no token: message on stderr" true (_has $STATE/err 'GITEA_TOKEN')
check "no token: stdout empty" 0 (_len $STATE/out)
set -gx GITEA_TOKEN tok-SECRET123

set -gx GITEA_URL ''
_bdp_run $FULL_BIN rootiest/test
check "no URL: exits 1" 1 $status
check "no URL: message on stderr" true (_has $STATE/err 'GITEA_URL')
check "no URL: stdout empty" 0 (_len $STATE/out)
set -gx GITEA_URL https://gitea.invalid
check "usage errors made no request" false (test -f $STATE/argv.log; and echo true; or echo false)

section "bd-pull: no issues"
_bdp_setup
echo '[]' >$STATE/page-1.json
_bdp_run $FULL_BIN rootiest/test
check "empty list exits 0" 0 $status
check "empty list says so" true (_has $STATE/out 'No unlinked issues')
check "empty list: a single request" 1 (_nlines $STATE/urls.log)
check "empty list: no commit" $BASE_SHA (git -C $REPO rev-parse HEAD)

cleanup
report
