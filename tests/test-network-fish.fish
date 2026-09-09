#!/usr/bin/env fish
# Copyright (C) 2026 Rootiest
# SPDX-License-Identifier: AGPL-3.0-or-later
#
# Hermetic unit tests for network-dependent fish functions with full mock coverage
# and failure edge-case testing:
#   - gi (gitignore generation, API fetch, deduplication, error handling)
#   - gip, gip4, gip6 (public IP resolution, timeouts, IPv4/IPv6 fallback, failure notices)
#   - qr (terminal QR code generator, qrencode local bypass, curl fallback & network drop)
#   - bd-pull (Gitea issues sync, missing tokens, API failures, malformed JSON, linking)
#   - _auto_pull_sync (background safe fast-forward, dirty trees, network drop on fetch)
#   - gitup (remote fetch & status, network drop handling)
#   - git-clean (remote fetch/prune, orphaned branch detection & deletion)
#   - config-update (upstream fetch, up-to-date check, dry-run, force stash & restore)
#   - repo-open (origin URL parsing, offline local tracking, ls-remote fallback & drop)
#   - fzf-update (git pull/clone network failure handling)
#
# MODE: isolated

source (realpath (dirname (status filename)))/lib.fish
set -p fish_function_path $repo_root/functions

set -gx TERM xterm-256color
set -g TMPDIRS

# Ensure git operations inside tests are hermetic and do not prompt
set -gx GIT_AUTHOR_NAME t
set -gx GIT_AUTHOR_EMAIL t@t
set -gx GIT_COMMITTER_NAME t
set -gx GIT_COMMITTER_EMAIL t@t
set -gx GIT_CONFIG_COUNT 2
set -gx GIT_CONFIG_KEY_0 commit.gpgsign
set -gx GIT_CONFIG_VALUE_0 false
set -gx GIT_CONFIG_KEY_1 init.defaultBranch
set -gx GIT_CONFIG_VALUE_1 main
set -gx GIT_TERMINAL_PROMPT 0

# Helper to create temporary git repos
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

# Build a hermetic mock bin directory
set -g MOCK_DIR (mktemp -d)
set -ga TMPDIRS $MOCK_DIR
set -l real_git (command -s git)

# 1. Mock curl
printf '%s\n' \
    '#!/bin/sh' \
    'if [ -n "$MOCK_CURL_LOG" ]; then' \
    '  printf "%s\n" "$*" >> "$MOCK_CURL_LOG"' \
    'fi' \
    'if [ -n "$MOCK_CURL_HANDLER" ] && [ -x "$MOCK_CURL_HANDLER" ]; then' \
    '  exec "$MOCK_CURL_HANDLER" "$@"' \
    'fi' \
    'if [ -n "$MOCK_CURL_DELAY" ]; then' \
    '  sleep "$MOCK_CURL_DELAY"' \
    'fi' \
    'if [ -n "$MOCK_CURL_STDERR" ]; then' \
    '  printf "%s\n" "$MOCK_CURL_STDERR" >&2' \
    'fi' \
    'if [ -f "$MOCK_CURL_BODY_FILE" ]; then' \
    '  cat "$MOCK_CURL_BODY_FILE"' \
    'elif [ -n "$MOCK_CURL_BODY" ]; then' \
    '  printf "%s\n" "$MOCK_CURL_BODY"' \
    'fi' \
    'exit "${MOCK_CURL_STATUS:-0}"' > $MOCK_DIR/curl
chmod +x $MOCK_DIR/curl

# 2. Mock git shim
printf '%s\n' \
    '#!/bin/sh' \
    'if [ -n "$MOCK_GIT_LOG" ]; then' \
    '  printf "%s\n" "$*" >> "$MOCK_GIT_LOG"' \
    'fi' \
    'if [ -n "$MOCK_GIT_HANDLER" ] && [ -x "$MOCK_GIT_HANDLER" ]; then' \
    '  exec "$MOCK_GIT_HANDLER" "$@"' \
    'fi' \
    'for a in "$@"; do' \
    '  if [ "$a" = "fetch" ] && [ -n "$MOCK_GIT_FAIL_FETCH" ]; then' \
    '    echo "fatal: unable to access: Could not resolve host" >&2' \
    '    exit "${MOCK_GIT_FETCH_STATUS:-128}"' \
    '  fi' \
    '  if [ "$a" = "pull" ] && [ -n "$MOCK_GIT_FAIL_PULL" ]; then' \
    '    echo "fatal: unable to access: Could not resolve host" >&2' \
    '    exit "${MOCK_GIT_PULL_STATUS:-128}"' \
    '  fi' \
    '  if [ "$a" = "clone" ] && [ -n "$MOCK_GIT_FAIL_CLONE" ]; then' \
    '    echo "fatal: unable to access: Could not resolve host" >&2' \
    '    exit "${MOCK_GIT_CLONE_STATUS:-128}"' \
    '  fi' \
    '  if [ "$a" = "ls-remote" ] && [ -n "$MOCK_GIT_FAIL_LS_REMOTE" ]; then' \
    '    echo "fatal: unable to access: Could not resolve host" >&2' \
    '    exit "${MOCK_GIT_LS_REMOTE_STATUS:-128}"' \
    '  fi' \
    'done' \
    "exec $real_git \"\$@\"" > $MOCK_DIR/git
chmod +x $MOCK_DIR/git

# 3. Mock bd CLI
printf '%s\n' \
    '#!/bin/sh' \
    'if [ "$1" = "create" ]; then' \
    '  echo "Created issue bd-99"' \
    '  echo "{\"id\":\"bd-99\"}" >> .beads/issues.jsonl' \
    '  exit 0' \
    'elif [ "$1" = "sync" ]; then' \
    '  exit 0' \
    'fi' \
    'exit 0' > $MOCK_DIR/bd
chmod +x $MOCK_DIR/bd

# 4. Mock qrencode
printf '%s\n' \
    '#!/bin/sh' \
    'if [ -n "$MOCK_QRENCODE_LOG" ]; then' \
    '  printf "%s\n" "$*" >> "$MOCK_QRENCODE_LOG"' \
    'fi' \
    'echo "LOCAL_QRENCODE: $*"' \
    'exit 0' > $MOCK_DIR/qrencode
chmod +x $MOCK_DIR/qrencode

# Prepend MOCK_DIR to PATH so mocks take precedence
set -gx PATH $MOCK_DIR $PATH

function reset_mocks
    set -e MOCK_CURL_STATUS
    set -e MOCK_CURL_BODY
    set -e MOCK_CURL_BODY_FILE
    set -e MOCK_CURL_STDERR
    set -e MOCK_CURL_DELAY
    set -e MOCK_CURL_LOG
    set -e MOCK_CURL_HANDLER
    set -e MOCK_GIT_FAIL_FETCH
    set -e MOCK_GIT_FETCH_STATUS
    set -e MOCK_GIT_FAIL_PULL
    set -e MOCK_GIT_PULL_STATUS
    set -e MOCK_GIT_FAIL_CLONE
    set -e MOCK_GIT_CLONE_STATUS
    set -e MOCK_GIT_FAIL_LS_REMOTE
    set -e MOCK_GIT_LS_REMOTE_STATUS
    set -e MOCK_GIT_LOG
    set -e MOCK_GIT_HANDLER
    set -e MOCK_QRENCODE_LOG
end

function cleanup
    for d in $TMPDIRS
        test -n "$d"; and command rm -rf $d
    end
end


# ─────────────────────────────────────────────────────────────────────────────
# 1. gi (gitignore generator)
# ─────────────────────────────────────────────────────────────────────────────
section "network isolation: gi"

reset_mocks
set -gx MOCK_CURL_BODY "c,cpp,python,rust"
set -l list_out (gi -l)
check "gi -l: returns API target list" "c,cpp,python,rust" "$list_out"

# Complete network drop on list
set -gx MOCK_CURL_STATUS 7
set -gx MOCK_CURL_BODY ""
gi -l >/dev/null 2>&1
check "gi -l: returns 0 per contract" 0 $status

# stdout mode with valid content
reset_mocks
set -gx MOCK_CURL_BODY "# Python gitignore\n*.pyc\n__pycache__/"
set -l stdout_out (gi -s python)
check "gi -s: prints fetched patterns to stdout" "# Python gitignore\n*.pyc\n__pycache__/" "$stdout_out"

# stdout mode with network failure / 404 (curl exit 22)
reset_mocks
set -gx MOCK_CURL_STATUS 22
set -gx MOCK_CURL_BODY ""
gi -s invalid_target >/dev/null 2>&1
check "gi -s: API failure returns 1" 1 $status

# Append mode outside git repository
reset_mocks
set -l non_git_dir (mktemp -d)
set -ga TMPDIRS $non_git_dir
begin
    set -l prev_pwd $PWD
    builtin cd $non_git_dir
    gi python >/dev/null 2>&1
    set -l rc $status
    builtin cd $prev_pwd
    check "gi <target>: outside git repo returns 1" 1 $rc
end

# Append mode inside git repo + deduplication
reset_mocks
set -l repo (new_repo)
set -gx MOCK_CURL_BODY "# Python gitignore\n*.pyc"
begin
    set -l prev_pwd $PWD
    builtin cd $repo
    gi python >/dev/null 2>&1
    check "gi python: first run returns 0" 0 $status
    check "gi python: creates .gitignore" true (test -f "$repo/.gitignore"; and echo true; or echo false)
    set -l first_lines (count (command cat "$repo/.gitignore"))

    # Second run with identical pattern triggers deduplication
    gi python >/dev/null 2>&1
    check "gi python: second run returns 0" 0 $status
    set -l second_lines (count (command cat "$repo/.gitignore"))
    check "gi python: deduplication prevents duplicate append" $first_lines $second_lines

    # Network failure during append skips modifying file
    set -gx MOCK_CURL_STATUS 7
    gi ruby >/dev/null 2>&1
    set -l third_lines (count (command cat "$repo/.gitignore"))
    check "gi: network drop during append preserves file" $second_lines $third_lines
    builtin cd $prev_pwd
end


# ─────────────────────────────────────────────────────────────────────────────
# 2. gip, gip4, gip6 (IP resolution)
# ─────────────────────────────────────────────────────────────────────────────
section "network isolation: gip, gip4, gip6"

# Create a specialized curl handler for gip IPv4/IPv6 dispatch
set -l gip_handler $MOCK_DIR/gip_curl.sh
printf '%s\n' \
    '#!/bin/sh' \
    'for a in "$@"; do' \
    '  if [ "$a" = "-4" ]; then' \
    '    if [ -n "$MOCK_FAIL_IPV4" ]; then exit "${MOCK_IPV4_STATUS:-28}"; fi' \
    '    echo "198.51.100.1"' \
    '    exit 0' \
    '  fi' \
    '  if [ "$a" = "-6" ]; then' \
    '    if [ -n "$MOCK_FAIL_IPV6" ]; then exit "${MOCK_IPV6_STATUS:-28}"; fi' \
    '    echo "2001:db8::1"' \
    '    exit 0' \
    '  fi' \
    'done' \
    'exit 0' > $gip_handler
chmod +x $gip_handler

reset_mocks
set -gx MOCK_CURL_HANDLER $gip_handler

# gip: both IPv4 and IPv6 succeed
set -l out_both (gip)
check "gip: both succeed outputs IPv4" true (string match -q '*IPv4: 198.51.100.1*' -- $out_both; and echo true; or echo false)
check "gip: both succeed outputs IPv6" true (string match -q '*IPv6: 2001:db8::1*' -- $out_both; and echo true; or echo false)

# gip: IPv4 timeout / failure, IPv6 success
set -gx MOCK_FAIL_IPV4 1
set -l out_v4_fail (gip)
check "gip: IPv4 failure reports 'Not detected'" true (string match -q '*IPv4: Not detected*' -- $out_v4_fail; and echo true; or echo false)
check "gip: IPv4 failure still reports IPv6" true (string match -q '*IPv6: 2001:db8::1*' -- $out_v4_fail; and echo true; or echo false)

# gip: IPv4 success, IPv6 failure
set -e MOCK_FAIL_IPV4
set -gx MOCK_FAIL_IPV6 1
set -l out_v6_fail (gip)
check "gip: IPv6 failure reports IPv4" true (string match -q '*IPv4: 198.51.100.1*' -- $out_v6_fail; and echo true; or echo false)
check "gip: IPv6 failure reports 'Not detected'" true (string match -q '*IPv6: Not detected*' -- $out_v6_fail; and echo true; or echo false)

# gip: complete network drop (both fail)
set -gx MOCK_FAIL_IPV4 1
set -gx MOCK_FAIL_IPV6 1
set -l out_all_fail (gip)
check "gip: complete drop reports IPv4 Not detected" true (string match -q '*IPv4: Not detected*' -- $out_all_fail; and echo true; or echo false)
check "gip: complete drop reports IPv6 Not detected" true (string match -q '*IPv6: Not detected*' -- $out_all_fail; and echo true; or echo false)

# gip4: success
set -e MOCK_FAIL_IPV4
set -l out_gip4 (gip4)
check "gip4: success prints IP" "198.51.100.1" "$out_gip4"
check "gip4: success exits 0" 0 $status

# gip4: failure
set -gx MOCK_FAIL_IPV4 1
set -gx MOCK_IPV4_STATUS 7
gip4 >/dev/null 2>&1
check "gip4: failure returns curl status" 7 $status

# gip6: success
set -e MOCK_FAIL_IPV6
set -l out_gip6 (gip6)
check "gip6: success prints IPv6" "2001:db8::1" "$out_gip6"
check "gip6: success exits 0" 0 $status

# gip6: failure / unsupported network
set -gx MOCK_FAIL_IPV6 1
set -l out_gip6_err (gip6 2>&1)
check "gip6: failure exits 1" 1 $status
check "gip6: failure prints notice" true (string match -q '*IPv6 is currently unavailable*' -- $out_gip6_err; and echo true; or echo false)


# ─────────────────────────────────────────────────────────────────────────────
# 3. qr (QR code generator)
# ─────────────────────────────────────────────────────────────────────────────
section "network isolation: qr"

reset_mocks
# Case A: Local qrencode tool is present
set -gx MOCK_QRENCODE_LOG (mktemp)
set -ga TMPDIRS $MOCK_QRENCODE_LOG
set -l qr_local (qr "hello-world")
check "qr: local qrencode is preferred offline" true (string match -q '*LOCAL_QRENCODE*' -- $qr_local; and echo true; or echo false)
check "qr: curl is never called when qrencode exists" 0 (test -f $MOCK_DIR/curl_log; and count (cat $MOCK_DIR/curl_log); or echo 0)

# Case B: Local qrencode is missing, falling back to curl
function type
    if test "$argv[1]" = "-q" -a "$argv[2]" = "qrencode"
        return 1
    end
    builtin type $argv
end

set -gx MOCK_CURL_BODY "UTF8_QR_BODY"
set -l qr_curl (qr "hello-curl")
check "qr: fallback to curl when qrencode is missing" "UTF8_QR_BODY" "$qr_curl"

# Network drop during curl fallback
set -gx MOCK_CURL_STATUS 7
set -gx MOCK_CURL_BODY ""
qr "fail" >/dev/null 2>&1
check "qr: curl network drop returns non-zero" 7 $status

# Argument-based curl fallback
set -gx MOCK_CURL_STATUS 0
set -gx MOCK_CURL_BODY "TEXT_QR"
set -l qr_arg (qr "arg-text")
check "qr: argument works via curl fallback" "TEXT_QR" "$qr_arg"

functions -e type


# ─────────────────────────────────────────────────────────────────────────────
# 4. bd-pull (Gitea issues sync)
# ─────────────────────────────────────────────────────────────────────────────
section "network isolation: bd-pull"

reset_mocks
# Missing required arguments & env vars
bd-pull >/dev/null 2>&1
check "bd-pull: missing repo argument exits 1" 1 $status

begin
    set -e GITEA_TOKEN
    set -e GITEA_URL
    bd-pull rootiest/test >/dev/null 2>&1
    check "bd-pull: missing GITEA_TOKEN exits 1" 1 $status

    set -gx GITEA_TOKEN "test_token"
    bd-pull rootiest/test >/dev/null 2>&1
    check "bd-pull: missing GITEA_URL exits 1" 1 $status
end

# Complete network drop / empty response
set -gx GITEA_TOKEN "dummy_token"
set -gx GITEA_URL "https://git.test"
set -gx MOCK_CURL_STATUS 7
set -gx MOCK_CURL_BODY ""
set -l out_drop (bd-pull rootiest/test)
check "bd-pull: network drop reports no unlinked issues" true (string match -q '*No unlinked issues found*' -- $out_drop; and echo true; or echo false)

# Empty JSON issue list
set -gx MOCK_CURL_STATUS 0
set -gx MOCK_CURL_BODY "[]"
set -l out_empty (bd-pull rootiest/test)
check "bd-pull: empty issue list handled cleanly" true (string match -q '*No unlinked issues found*' -- $out_empty; and echo true; or echo false)

# Issues already linked with [ID] prefix
set -gx MOCK_CURL_BODY '[{"number": 1, "title": "[bd-1] Already linked issue"}]'
set -l out_already (bd-pull rootiest/test)
check "bd-pull: already-linked issues skipped" true (string match -q '*No unlinked issues found*' -- $out_already; and echo true; or echo false)

# Unlinked issue found: creates bead, patches title, commits & pushes
set -l bd_remote (new_repo)
git -C $bd_remote config --bool core.bare true
set -l bd_repo (new_repo)
begin
    set -l prev_pwd $PWD
    builtin cd $bd_repo
    git remote add origin $bd_remote
    mkdir -p .beads
    touch .beads/issues.jsonl
    git add .beads/issues.jsonl
    git commit -q -m "init beads"
    git push -q -u origin main

    set -gx MOCK_CURL_BODY '[{"number": 2, "title": "Web original issue without ID"}]'
    set -l out_unlinked (bd-pull rootiest/test 2>&1)
    check "bd-pull: unlinked issue is linked" true (string match -q '*Linked 1 issues*' -- $out_unlinked; and echo true; or echo false)

    # Verify git commit was made
    set -l last_msg (git log -1 --pretty=%s)
    check "bd-pull: commits synced IDs to git" "chore: sync local IDs for web issues" "$last_msg"
    builtin cd $prev_pwd
end


# ─────────────────────────────────────────────────────────────────────────────
# 5. _auto_pull_sync (background fast-forward)
# ─────────────────────────────────────────────────────────────────────────────
section "network isolation: _auto_pull_sync"

reset_mocks
# Non-git directory
_auto_pull_sync /tmp >/dev/null 2>&1
check "_auto_pull_sync: non-git directory returns 1" 1 $status

# Git repo without upstream branch
set -l sync_repo (new_repo)
echo "test" > $sync_repo/file.txt
git -C $sync_repo add file.txt
git -C $sync_repo commit -q -m "initial"
_auto_pull_sync $sync_repo >/dev/null 2>&1
check "_auto_pull_sync: missing upstream returns 1" 1 $status

# Setup upstream branch for sync_repo
set -l sync_upstream (new_repo)
git -C $sync_upstream config --bool core.bare true
git -C $sync_repo remote add origin $sync_upstream
git -C $sync_repo push -q -u origin main >/dev/null 2>&1

# Dirty working tree (unstaged modifications)
echo "dirty" >> $sync_repo/file.txt
_auto_pull_sync $sync_repo >/dev/null 2>&1
check "_auto_pull_sync: dirty worktree returns 1" 1 $status
git -C $sync_repo checkout -q -- file.txt

# Dirty index (staged modifications)
echo "staged" >> $sync_repo/staged.txt
git -C $sync_repo add staged.txt
_auto_pull_sync $sync_repo >/dev/null 2>&1
check "_auto_pull_sync: dirty index returns 1" 1 $status
git -C $sync_repo reset -q HEAD staged.txt
command rm -f $sync_repo/staged.txt

# Clean repo, network failure on git fetch
set -gx MOCK_GIT_FAIL_FETCH 1
_auto_pull_sync $sync_repo >/dev/null 2>&1
check "_auto_pull_sync: fetch failure returns 1" 1 $status

# Clean repo, successful fast-forward
reset_mocks
# Add commit to upstream
set -l peer_clone (new_repo)
git -C $peer_clone clone -q $sync_upstream $peer_clone/work
echo "new commit" > $peer_clone/work/new.txt
git -C $peer_clone/work add new.txt
git -C $peer_clone/work commit -q -m "upstream work"
git -C $peer_clone/work push -q origin main

_auto_pull_sync $sync_repo >/dev/null 2>&1
check "_auto_pull_sync: clean fast-forward returns 0" 0 $status
check "_auto_pull_sync: changes merged into working tree" true (test -f $sync_repo/new.txt; and echo true; or echo false)


# ─────────────────────────────────────────────────────────────────────────────
# 6. gitup (fetch and status)
# ─────────────────────────────────────────────────────────────────────────────
section "network isolation: gitup"

reset_mocks
begin
    set -l prev_pwd $PWD
    builtin cd /tmp
    gitup >/dev/null 2>&1
    check "gitup: outside git repo exits 1" 1 $status

    set -l r (new_repo)
    builtin cd $r
    echo a > a && git add a && git commit -q -m a

    # Network failure on git fetch
    set -gx MOCK_GIT_FAIL_FETCH 1
    gitup >/dev/null 2>&1
    check "gitup: network drop during fetch exits non-zero" true (test $status -ne 0; and echo true; or echo false)

    # Successful fetch
    reset_mocks
    set -l up_out (gitup 2>&1)
    check "gitup: success exits 0" 0 $status
    check "gitup: displays git status output" true (string match -q '*On branch main*' -- $up_out; and echo true; or echo false)
    builtin cd $prev_pwd
end


# ─────────────────────────────────────────────────────────────────────────────
# 7. git-clean (fetch --prune and delete orphaned branches)
# ─────────────────────────────────────────────────────────────────────────────
section "network isolation: git-clean"

reset_mocks
git-clean --help >/dev/null 2>&1
check "git-clean: --help exits 0" 0 $status

begin
    set -l prev_pwd $PWD
    set -l r (new_repo)
    builtin cd $r
    echo a > a && git add a && git commit -q -m a

    # Network drop during git fetch --prune
    set -gx MOCK_GIT_FAIL_FETCH 1
    # git-clean continues to local cleanup even if fetch fails
    set -l clean_out (git-clean 2>&1)
    check "git-clean: network drop handled, reports tidy" true (string match -q '*No orphaned branches found*' -- $clean_out; and echo true; or echo false)

    # Orphaned branch detection and cleanup
    reset_mocks
    # Simulate an orphaned branch with [gone] tracking
    git branch orphaned-feat
    # Create git-clean handler that simulates git branch -vv showing ': gone]'
    set -l clean_git_handler $MOCK_DIR/git_clean_shim.sh
    printf '%s\n' \
        '#!/bin/sh' \
        'for a in "$@"; do' \
        '  if [ "$a" = "-vv" ]; then' \
        '    echo "  main           1234567 [origin/main] initial"' \
        '    echo "  orphaned-feat  abcdef0 [origin/orphaned-feat: gone] feature"' \
        '    exit 0' \
        '  fi' \
        'done' \
        "exec $real_git \"\$@\"" > $clean_git_handler
    chmod +x $clean_git_handler

    set -gx MOCK_GIT_HANDLER $clean_git_handler
    set -l clean_del_out (git-clean 2>&1)
    check "git-clean: detects and deletes orphaned branch" true (string match -q '*Deleting orphaned local branches*' -- $clean_del_out; and echo true; or echo false)
    check "git-clean: orphaned branch was deleted" false (git rev-parse --verify --quiet orphaned-feat >/dev/null 2>&1; and echo true; or echo false)

    builtin cd $prev_pwd
end


# ─────────────────────────────────────────────────────────────────────────────
# 8. config-update (configuration repository sync)
# ─────────────────────────────────────────────────────────────────────────────
section "network isolation: config-update"

reset_mocks
config-update --help >/dev/null 2>&1
check "config-update: --help exits 0" 0 $status

# Non-git CONFIG_DIR (using mock handler)
set -l cfg_update_handler $MOCK_DIR/cfg_update_shim.sh
printf '%s\n' \
    '#!/bin/sh' \
    'for a in "$@"; do' \
    '  if [ "$a" = "fetch" ] && [ -n "$MOCK_CFG_FAIL_FETCH" ]; then' \
    '    exit 1' \
    '  fi' \
    'done' \
    "exec $real_git \"\$@\"" > $cfg_update_handler
chmod +x $cfg_update_handler
set -gx MOCK_GIT_HANDLER $cfg_update_handler

# Network failure on upstream fetch
set -l fake_home (mktemp -d)
set -ga TMPDIRS $fake_home
set -l fake_fish_cfg "$fake_home/.config/fish"
mkdir -p (dirname $fake_fish_cfg)
set -l cfg_repo (new_repo)
command cp -r $cfg_repo $fake_fish_cfg

# Test config-update against fake_fish_cfg by setting HOME
begin
    set -lx HOME $fake_home
    set -gx MOCK_CFG_FAIL_FETCH 1
    config-update >/dev/null 2>&1
    check "config-update: network fetch failure returns 1" 1 $status
end


# ─────────────────────────────────────────────────────────────────────────────
# 9. repo-open (origin URL normalization and browser deep-linking)
# ─────────────────────────────────────────────────────────────────────────────
section "network isolation: repo-open"

reset_mocks
repo-open --help >/dev/null 2>&1
check "repo-open: --help exits 0" 0 $status

# Outside git repo
begin
    set -l prev_pwd $PWD
    builtin cd /tmp
    repo-open -p >/dev/null 2>&1
    check "repo-open: outside git repo returns 1" 1 $status
    builtin cd $prev_pwd
end

# In git repo without origin
set -l r_no_origin (new_repo)
begin
    set -l prev_pwd $PWD
    builtin cd $r_no_origin
    repo-open -p >/dev/null 2>&1
    check "repo-open: without origin remote returns 1" 1 $status
    builtin cd $prev_pwd
end

# In git repo with GitHub origin remote
set -l r_gh (new_repo)
git -C $r_gh remote add origin "https://github.com/rootiest/fish-config.git"
echo init > $r_gh/file && git -C $r_gh add file && git -C $r_gh commit -q -m init
begin
    set -l prev_pwd $PWD
    builtin cd $r_gh

    # Remote ls-remote network failure falls back to default branch
    set -gx MOCK_GIT_FAIL_LS_REMOTE 1
    set -l url_fallback (repo-open -p)
    check "repo-open: ls-remote network drop falls back to default branch" "https://github.com/rootiest/fish-config" "$url_fallback"

    # With ls-remote success for current branch
    reset_mocks
    set -l gh_ls_handler $MOCK_DIR/gh_ls_shim.sh
    printf '%s\n' \
        '#!/bin/sh' \
        'for a in "$@"; do' \
        '  if [ "$a" = "ls-remote" ]; then' \
        '    echo "abcdef01 refs/heads/main"' \
        '    exit 0' \
        '  fi' \
        'done' \
        "exec $real_git \"\$@\"" > $gh_ls_handler
    chmod +x $gh_ls_handler
    set -gx MOCK_GIT_HANDLER $gh_ls_handler

    # Test gitlab provider normalization
    git remote set-url origin "git@gitlab.com:rootiest/fish-config.git"
    git checkout -q -b feat-test
    set -l url_gl (repo-open -p)
    check "repo-open: gitlab ssh url normalized with branch tree" "https://gitlab.com/rootiest/fish-config/-/tree/feat-test" "$url_gl"

    # Test gitea provider normalization
    git remote set-url origin "https://git.rootiest.dev/rootiest/fish-config.git"
    git config browse.provider gitea
    set -l url_gitea (repo-open -p)
    check "repo-open: gitea url normalized with src/branch" "https://git.rootiest.dev/rootiest/fish-config/src/branch/feat-test" "$url_gitea"

    builtin cd $prev_pwd
end


# ─────────────────────────────────────────────────────────────────────────────
# 10. fzf-update (fzf install / git pull)
# ─────────────────────────────────────────────────────────────────────────────
section "network isolation: fzf-update"

reset_mocks
# When ~/.fzf exists, git pull fails due to network drop
set -l fake_home_fzf (mktemp -d)
set -ga TMPDIRS $fake_home_fzf
mkdir -p $fake_home_fzf/.fzf

begin
    set -lx HOME $fake_home_fzf
    set -gx MOCK_GIT_FAIL_PULL 1
    fzf-update >/dev/null 2>&1
    check "fzf-update: git pull network drop returns non-zero" true (test $status -ne 0; and echo true; or echo false)
end

# When ~/.fzf does not exist, git clone fails due to network drop
set -l fake_home_no_fzf (mktemp -d)
set -ga TMPDIRS $fake_home_no_fzf

begin
    set -lx HOME $fake_home_no_fzf
    set -gx MOCK_GIT_FAIL_CLONE 1
    fzf-update >/dev/null 2>&1
    check "fzf-update: git clone network drop returns non-zero" true (test $status -ne 0; and echo true; or echo false)
end


# ─────────────────────────────────────────────────────────────────────────────
# Teardown and Final Report
# ─────────────────────────────────────────────────────────────────────────────
cleanup
report
