#!/usr/bin/env fish
# Copyright (C) 2026 Rootiest
# SPDX-License-Identifier: AGPL-3.0-or-later
#
# Hermetic unit tests for network-dependent fish functions with full mock coverage
# and failure edge-case testing:
#   - gi (gitignore generation, API fetch, deduplication, error handling)
#   - gip, gip4, gip6 (public IP resolution, timeouts, IPv4/IPv6 fallback, failure notices)
#   - qr (terminal QR code generator, qrencode local bypass, opt-in --online curl fallback, URL encoding & network drop)
#   - bd-pull (Gitea issues sync, missing tokens, API failures, malformed JSON, linking)
#   - _auto_pull_sync (background safe fast-forward, dirty trees, network drop on fetch)
#   - gitup (remote fetch & status, network drop handling)
#   - git-sweep / git-clean (fetch/prune, merged & orphaned branch cleanup, open-PR lookup fallbacks)
#   - config-update (upstream fetch, up-to-date check, dry-run, force stash & restore)
#   - repo-open (origin URL parsing, offline local tracking, ls-remote fallback & drop)
#   - fzf-update (git pull/clone network failure handling)
#
# MODE: isolated

source (realpath (dirname (status filename)))/lib.fish
set -p fish_function_path $repo_root/functions

# Isolated runs sandbox XDG_CONFIG_HOME to an empty dir, and __fish_config_dir
# is read-only under --no-config, so gi's bundled boilerplate fallback
# (data/gi/boilerplate.gitignore) needs the real file reachable wherever
# __fish_config_dir actually points. Same pattern as
# test-string-and-expansion.fish uses for rand_string's data/words/.
if not test -d "$__fish_config_dir/data/gi"
    mkdir -p "$__fish_config_dir/data"
    ln -sf "$repo_root/data/gi" "$__fish_config_dir/data/gi"
end

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
    fi \
    'if [ -n "$MOCK_CURL_HANDLER" ] && [ -x "$MOCK_CURL_HANDLER" ]; then' \
    '  exec "$MOCK_CURL_HANDLER" "$@"' \
    fi \
    'if [ -n "$MOCK_CURL_DELAY" ]; then' \
    '  sleep "$MOCK_CURL_DELAY"' \
    fi \
    'if [ -n "$MOCK_CURL_STDERR" ]; then' \
    '  printf "%s\n" "$MOCK_CURL_STDERR" >&2' \
    fi \
    'if [ -f "$MOCK_CURL_BODY_FILE" ]; then' \
    '  cat "$MOCK_CURL_BODY_FILE"' \
    'elif [ -n "$MOCK_CURL_BODY" ]; then' \
    '  printf "%s\n" "$MOCK_CURL_BODY"' \
    fi \
    'exit "${MOCK_CURL_STATUS:-0}"' >$MOCK_DIR/curl
chmod +x $MOCK_DIR/curl

# 2. Mock git shim
printf '%s\n' \
    '#!/bin/sh' \
    'if [ -n "$MOCK_GIT_LOG" ]; then' \
    '  printf "%s\n" "$*" >> "$MOCK_GIT_LOG"' \
    fi \
    'if [ -n "$MOCK_GIT_HANDLER" ] && [ -x "$MOCK_GIT_HANDLER" ]; then' \
    '  exec "$MOCK_GIT_HANDLER" "$@"' \
    fi \
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
    done \
    "exec $real_git \"\$@\"" >$MOCK_DIR/git
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
    fi \
    'exit 0' >$MOCK_DIR/bd
chmod +x $MOCK_DIR/bd

# 4. Mock qrencode
printf '%s\n' \
    '#!/bin/sh' \
    'if [ -n "$MOCK_QRENCODE_LOG" ]; then' \
    '  printf "%s\n" "$*" >> "$MOCK_QRENCODE_LOG"' \
    fi \
    'echo "LOCAL_QRENCODE: $*"' \
    'exit 0' >$MOCK_DIR/qrencode
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
set -l stdout_out (gi -o python)
check "gi -o: prints fetched patterns to stdout" "# Python gitignore\n*.pyc\n__pycache__/" "$stdout_out"

# stdout mode with network failure / 404 (curl exit 22)
reset_mocks
set -gx MOCK_CURL_STATUS 22
set -gx MOCK_CURL_BODY ""
gi -o invalid_target >/dev/null 2>&1
check "gi -o: API failure returns 1" 1 $status

# Regression: default mode (no args/flags) + --stdout must not touch .gitignore
reset_mocks
set -l stdout_repo (new_repo)
set -l boilerplate_file (mktemp)
set -ga TMPDIRS $boilerplate_file
printf '%s\n' '*.log' >$boilerplate_file
begin
    set -l prev_pwd $PWD
    builtin cd $stdout_repo
    set -gx GITIGNORE_BOILERPLATE $boilerplate_file
    set -l default_stdout_out (echo "" | gi -o -s)
    set -e GITIGNORE_BOILERPLATE
    builtin cd $prev_pwd
    check "gi -o (default mode): boilerplate goes to stdout" "*.log" "$default_stdout_out"
    check "gi -o (default mode): does not create .gitignore" false (test -f "$stdout_repo/.gitignore"; and echo true; or echo false)
end

# Regression: stdout mode must return 0 on success, not leak needs_git's test status
reset_mocks
set -gx MOCK_CURL_BODY "# Python gitignore\n*.pyc"
gi -o python >/dev/null 2>&1
check "gi -o: success returns 0" 0 $status

# Boilerplate: unset $GITIGNORE_BOILERPLATE falls back to the bundled standard template
reset_mocks
set -l fallback_repo (new_repo)
begin
    set -l prev_pwd $PWD
    builtin cd $fallback_repo
    set -e GITIGNORE_BOILERPLATE
    gi -b -s >/dev/null 2>&1
    set -l rc $status
    builtin cd $prev_pwd
    check "gi -b (no env var): falls back returns 0" 0 $rc
    check "gi -b (no env var): appends bundled template content" true \
        (grep -qF ".Trash-*" "$fallback_repo/.gitignore"; and echo true; or echo false)
end

# Boilerplate: -c/--custom overrides $GITIGNORE_BOILERPLATE
reset_mocks
set -l custom_repo (new_repo)
set -l custom_file (mktemp)
set -ga TMPDIRS $custom_file
set -l env_file (mktemp)
set -ga TMPDIRS $env_file
printf '%s\n' from-custom-flag/ >$custom_file
printf '%s\n' from-env-var/ >$env_file
begin
    set -l prev_pwd $PWD
    builtin cd $custom_repo
    set -gx GITIGNORE_BOILERPLATE $env_file
    gi -c $custom_file -s >/dev/null 2>&1
    set -e GITIGNORE_BOILERPLATE
    builtin cd $prev_pwd
    check "gi -c: uses custom template over env var" true \
        (grep -qF "from-custom-flag/" "$custom_repo/.gitignore"; and echo true; or echo false)
    check "gi -c: does not use env var template" false \
        (grep -qF "from-env-var/" "$custom_repo/.gitignore"; and echo true; or echo false)
end

# Boilerplate: -c alone (no -b) still runs boilerplate mode, and a missing
# custom template reports an error without touching .gitignore
reset_mocks
set -l custom_missing_repo (new_repo)
begin
    set -l prev_pwd $PWD
    builtin cd $custom_missing_repo
    gi -c /nonexistent/template.gitignore -s >/dev/null 2>&1
    builtin cd $prev_pwd
    check "gi -c: missing template leaves no .gitignore" false \
        (test -f "$custom_missing_repo/.gitignore"; and echo true; or echo false)
end

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
    done \
    'exit 0' >$gip_handler
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
    if test "$argv[1]" = -q -a "$argv[2]" = qrencode
        return 1
    end
    builtin type $argv
end

# Without --online, nothing leaves the machine (#225)
set -gx MOCK_CURL_LOG (mktemp)
set -ga TMPDIRS $MOCK_CURL_LOG
set -l qr_err (qr "secret" 2>&1 >/dev/null)
check "qr: missing qrencode without --online exits 1" 1 $status
check "qr: missing qrencode without --online explains itself" true (string match -q '*--online*' -- $qr_err; and echo true; or echo false)
check "qr: curl is never called without --online" 0 (count (cat $MOCK_CURL_LOG))

set -gx MOCK_CURL_BODY UTF8_QR_BODY
set -l qr_curl (qr --online "hello-curl")
check "qr: --online falls back to curl when qrencode is missing" UTF8_QR_BODY "$qr_curl"

# Network drop during curl fallback
set -gx MOCK_CURL_STATUS 7
set -gx MOCK_CURL_BODY ""
qr --online fail >/dev/null 2>&1
check "qr: curl network drop returns non-zero" 7 $status

# Argument-based curl fallback
set -gx MOCK_CURL_STATUS 0
set -gx MOCK_CURL_BODY TEXT_QR
set -l qr_arg (qr -o "arg-text")
check "qr: argument works via curl fallback" TEXT_QR "$qr_arg"

# Text is URL-encoded and arguments are joined into one request
echo -n >$MOCK_CURL_LOG
qr --online "a#b?c" d >/dev/null
check "qr: --online makes exactly one request" 1 (count (cat $MOCK_CURL_LOG))
check "qr: --online URL-encodes the text" true (string match -q '*https://qrenco.de/a%23b%3Fc%20d' -- (cat $MOCK_CURL_LOG); and echo true; or echo false)
check "qr: --online fails on HTTP errors with a timeout" true (string match -q -- '-fsS --max-time *' (cat $MOCK_CURL_LOG); and echo true; or echo false)

# Multi-line stdin is one encoded request
echo -n >$MOCK_CURL_LOG
printf 'line1\nline2\n' | qr --online >/dev/null
check "qr: multi-line stdin URL-encodes the newline" true (string match -q '*/line1%0Aline2' -- (cat $MOCK_CURL_LOG); and echo true; or echo false)

functions -e type

# ─────────────────────────────────────────────────────────────────────────────
# 4. bd-pull (Gitea issues sync)
# ─────────────────────────────────────────────────────────────────────────────
section "network isolation: bd-pull"

reset_mocks
# Missing required arguments & env vars
bd-pull >/dev/null 2>&1
check "bd-pull: missing repo argument exits 2" 2 $status

begin
    set -e GITEA_TOKEN
    set -e GITEA_URL
    bd-pull rootiest/test >/dev/null 2>&1
    check "bd-pull: missing GITEA_TOKEN exits 1" 1 $status

    set -gx GITEA_TOKEN test_token
    bd-pull rootiest/test >/dev/null 2>&1
    check "bd-pull: missing GITEA_URL exits 1" 1 $status
end

# Complete network drop / empty response
set -gx GITEA_TOKEN dummy_token
set -gx GITEA_URL "https://git.test"
set -gx MOCK_CURL_STATUS 7
set -gx MOCK_CURL_BODY ""
set -l out_drop (bd-pull rootiest/test 2>&1)
set -l code_drop $status
check "bd-pull: network drop exits 1" 1 $code_drop
check "bd-pull: network drop is reported, not read as an empty list" true (string match -q '*Gitea request failed*' -- $out_drop; and echo true; or echo false)

# The shared curl mock serves one body for every request, so give bd-pull a
# handler that serves it for page 1 only and an empty list for any later page
# (and nothing for the title PATCH).
set -g BD_PULL_HANDLER (mktemp)
set -ga TMPDIRS $BD_PULL_HANDLER
printf '%s\n' \
    '#!/bin/sh' \
    'case "$*" in' \
    '  *page=1) printf "%s\n" "$MOCK_CURL_BODY" ;;' \
    '  *page=*) echo "[]" ;;' \
    esac \
    'exit 0' >$BD_PULL_HANDLER
chmod +x $BD_PULL_HANDLER
set -gx MOCK_CURL_HANDLER $BD_PULL_HANDLER

# Empty JSON issue list
set -gx MOCK_CURL_STATUS 0
set -gx MOCK_CURL_BODY "[]"
set -l out_empty (bd-pull rootiest/test)
check "bd-pull: empty issue list handled cleanly" true (string match -q '*No unlinked issues found*' -- $out_empty; and echo true; or echo false)

# Issues already linked with [ID] prefix
set -gx MOCK_CURL_BODY '[{"number": 1, "title": "[bd-1] Already linked issue"}]'
set -l out_already (bd-pull rootiest/test)
check "bd-pull: already-linked issues skipped" true (string match -q '*No unlinked issues found*' -- $out_already; and echo true; or echo false)

# Unlinked issue found: creates bead, patches title, commits (no push without --push)
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
echo test >$sync_repo/file.txt
git -C $sync_repo add file.txt
git -C $sync_repo commit -q -m initial
_auto_pull_sync $sync_repo >/dev/null 2>&1
check "_auto_pull_sync: missing upstream returns 1" 1 $status

# Setup upstream branch for sync_repo
set -l sync_upstream (new_repo)
git -C $sync_upstream config --bool core.bare true
git -C $sync_repo remote add origin $sync_upstream
git -C $sync_repo push -q -u origin main >/dev/null 2>&1

# Dirty working tree (unstaged modifications)
echo dirty >>$sync_repo/file.txt
_auto_pull_sync $sync_repo >/dev/null 2>&1
check "_auto_pull_sync: dirty worktree returns 1" 1 $status
git -C $sync_repo checkout -q -- file.txt

# Dirty index (staged modifications)
echo staged >>$sync_repo/staged.txt
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
echo "new commit" >$peer_clone/work/new.txt
git -C $peer_clone/work add new.txt
git -C $peer_clone/work commit -q -m "upstream work"
git -C $peer_clone/work push -q origin main

_auto_pull_sync $sync_repo >/dev/null 2>&1
check "_auto_pull_sync: clean fast-forward returns 0" 0 $status
check "_auto_pull_sync: changes merged into working tree" true (test -f $sync_repo/new.txt; and echo true; or echo false)

# Background fetch must never prompt (#205). A handler records the environment
# git's fetch sees. The suite-wide GIT_TERMINAL_PROMPT is dropped so only the
# function under test can supply it.
reset_mocks
set -l env_log (mktemp)
set -l env_handler (mktemp)
set -ga TMPDIRS $env_log $env_handler
printf '%s\n' \
    '#!/bin/sh' \
    'case " $* " in *" fetch "*)' \
    '  printf "PROMPT=%s\nASKPASS=%s\nSSH_ASKPASS=%s\nSSH_CMD=%s\nARGS=%s\n" \\' \
    '    "$GIT_TERMINAL_PROMPT" "$GIT_ASKPASS" "$SSH_ASKPASS" "$GIT_SSH_COMMAND" "$*" >>"$MOCK_ENV_LOG" ;;' \
    esac \
    "exec $real_git \"\$@\"" >$env_handler
chmod +x $env_handler
set -gx MOCK_GIT_HANDLER $env_handler
set -gx MOCK_ENV_LOG $env_log

set -e -g GIT_TERMINAL_PROMPT
set -e GIT_SSH_COMMAND
# A logging timeout(1) stub shows whether the fetch runs under a hard bound.
set -l timeout_dir (mktemp -d)
set -ga TMPDIRS $timeout_dir
printf '%s\n' \
    '#!/bin/sh' \
    'printf "TIMEOUT=%s\n" "$1" >>"$MOCK_ENV_LOG"' \
    shift \
    'exec "$@"' >$timeout_dir/timeout
chmod +x $timeout_dir/timeout
begin
    set -lx PATH $timeout_dir $PATH
    _auto_pull_sync $sync_repo >/dev/null 2>&1
end
check "_auto_pull_sync: fetch runs with GIT_TERMINAL_PROMPT=0" PROMPT=0 (string match 'PROMPT=*' <$env_log)
check "_auto_pull_sync: fetch runs with a no-op GIT_ASKPASS" ASKPASS=true (string match 'ASKPASS=*' <$env_log)
check "_auto_pull_sync: fetch runs with a no-op SSH_ASKPASS" SSH_ASKPASS=true (string match 'SSH_ASKPASS=*' <$env_log)
check "_auto_pull_sync: ssh runs in batch mode with a connect timeout" \
    "SSH_CMD=ssh -o BatchMode=yes -o ConnectTimeout=10" (string match 'SSH_CMD=*' <$env_log)
check "_auto_pull_sync: fetch runs under timeout(1)" TIMEOUT=60 (string match 'TIMEOUT=*' <$env_log)

# A user-set GIT_SSH_COMMAND is extended, not replaced.
command truncate -s 0 $env_log
begin
    set -lx GIT_SSH_COMMAND 'ssh -i /tmp/key'
    _auto_pull_sync $sync_repo >/dev/null 2>&1
end
check "_auto_pull_sync: user GIT_SSH_COMMAND is preserved" \
    "SSH_CMD=ssh -i /tmp/key -o BatchMode=yes -o ConnectTimeout=10" (string match 'SSH_CMD=*' <$env_log)

# So is a repo's core.sshCommand, which GIT_SSH_COMMAND would otherwise override.
command truncate -s 0 $env_log
git -C $sync_repo config core.sshCommand 'ssh -p 2222'
begin
    set -e GIT_SSH_COMMAND
    _auto_pull_sync $sync_repo >/dev/null 2>&1
end
check "_auto_pull_sync: core.sshCommand is preserved" \
    "SSH_CMD=ssh -p 2222 -o BatchMode=yes -o ConnectTimeout=10" (string match 'SSH_CMD=*' <$env_log)
git -C $sync_repo config --unset core.sshCommand
set -e MOCK_GIT_HANDLER MOCK_ENV_LOG
set -gx GIT_TERMINAL_PROMPT 0

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
    echo a >a && git add a && git commit -q -m a

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
# 7. git-sweep and git-clean (merged and orphaned branch cleanup)
# ─────────────────────────────────────────────────────────────────────────────
section "network isolation: git-sweep"

reset_mocks
git-sweep --help >/dev/null 2>&1
check "git-sweep: --help exits 0" 0 $status
git-sweep --bogus >/dev/null 2>&1
check "git-sweep: unknown option exits 2" 2 $status
git-sweep stray >/dev/null 2>&1
check "git-sweep: unexpected argument exits 2" 2 $status
git-clean --help >/dev/null 2>&1
check "git-clean: --help exits 0" 0 $status

begin
    set -l prev_pwd $PWD
    builtin cd (mktemp -d)
    git-sweep >/dev/null 2>&1
    check "git-sweep: outside a work tree exits 2" 2 $status
    builtin cd $prev_pwd
end

# Clone of a real local bare remote, one branch per case, cwd left inside it.
# The remote has no host, so tests stub the PR lister (below) to decide.
function sweep_fixture
    set -l bare (mktemp -d)
    set -ga TMPDIRS $bare
    git init -q --bare $bare
    builtin cd (new_repo)
    echo base >base && git add base && git commit -q -m base
    git remote add origin $bare
    git push -q -u origin main 2>/dev/null
    git remote set-head origin main >/dev/null 2>&1
    for b in r-merged r-squash r-rebase r-ff gone-merged gone-unmerged open-pr wip wt-branch release/1.0
        set -l file (string replace -a / _ -- $b)
        git switch -q -c $b main
        echo 1 >$file && git add $file && git commit -q -m "$b 1"
        echo 2 >>$file && git add $file && git commit -q -m "$b 2"
        git push -q -u origin $b 2>/dev/null
        git switch -q main
    end
    git merge -q --ff-only r-ff
    for b in r-merged gone-merged open-pr wt-branch release/1.0
        git merge -q --no-ff -m "merge $b" $b
    end
    git merge -q --squash r-squash >/dev/null 2>&1
    git commit -q -m "squash r-squash"
    git cherry-pick r-rebase~1 r-rebase >/dev/null
    git push -q origin main 2>/dev/null
    git push -q origin --delete gone-merged gone-unmerged 2>/dev/null
    set -l wt (mktemp -d)
    set -ga TMPDIRS $wt
    git worktree add -q $wt/wt wt-branch 2>/dev/null
    git switch -q -c fresh main
    git switch -q main
    # Leave local main behind origin/main to exercise the fast-forward.
    git reset -q --hard HEAD~2
end

function has_local --argument-names b
    git show-ref --verify --quiet refs/heads/$b; and echo true; or echo false
end

function has_remote --argument-names b
    git ls-remote --exit-code --heads origin refs/heads/$b >/dev/null 2>&1; and echo true; or echo false
end

# git-sweep's decisions are tested against a stub PR list; the real lister
# is tested on its own further down.
function _git_sweep_open_prs
    set -q SWEEP_PR_FAIL; and return 1
    set -q SWEEP_OPEN_PRS[1]; and printf '%s\n' $SWEEP_OPEN_PRS
    return 0
end

begin
    reset_mocks
    set -l prev_pwd $PWD
    sweep_fixture
    set -gx SWEEP_OPEN_PRS open-pr

    set -l dry_out (git-sweep --dry-run 2>&1)
    check "git-sweep: --dry-run exits 0" 0 $status
    check "git-sweep: --dry-run plans the squash-merged branch" true (string match -q '*delete*r-squash*squash-merged*' -- $dry_out; and echo true; or echo false)
    check "git-sweep: --dry-run keeps local branches" true (has_local r-merged)
    check "git-sweep: --dry-run keeps remote branches" true (has_remote r-merged)

    set -l base refs/remotes/origin/main
    check "_git_sweep_merged: merge commit" merged (_git_sweep_merged refs/heads/r-merged $base)
    check "_git_sweep_merged: fast-forward" merged (_git_sweep_merged refs/heads/r-ff $base)
    check "_git_sweep_merged: rebase merge" rebase-merged (_git_sweep_merged refs/heads/r-rebase $base)
    check "_git_sweep_merged: squash merge" squash-merged (_git_sweep_merged refs/heads/r-squash $base)
    _git_sweep_merged refs/heads/wip $base >/dev/null
    check "_git_sweep_merged: unmerged work fails" 1 $status

    git switch -q r-squash
    set -l out (git-sweep 2>&1)
    check "git-sweep: cleanup exits 0" 0 $status
    for b in r-merged r-squash r-rebase r-ff gone-merged
        check "git-sweep: deletes merged local $b" false (has_local $b)
    end
    for b in r-merged r-squash r-rebase r-ff
        check "git-sweep: deletes merged remote $b" false (has_remote $b)
    end
    check "git-sweep: keeps a gone branch with unmerged commits" true (has_local gone-unmerged)
    check "git-sweep: keeps the remote head of an open PR" true (has_remote open-pr)
    check "git-sweep: keeps a local branch tracking an open PR" true (has_local open-pr)
    check "git-sweep: keeps unmerged local work" true (has_local wip)
    check "git-sweep: keeps unmerged remote work" true (has_remote wip)
    check "git-sweep: keeps protected local release/1.0" true (has_local release/1.0)
    check "git-sweep: keeps protected remote release/1.0" true (has_remote release/1.0)
    check "git-sweep: keeps a never-committed branch" true (has_local fresh)
    check "git-sweep: keeps a branch checked out in another worktree" true (has_local wt-branch)
    check "git-sweep: switches off the deleted current branch" main (git branch --show-current)
    check "git-sweep: fast-forwards main" (git rev-parse origin/main) (git rev-parse main)
    check "git-sweep: prints a restore hint" true (string match -q '*git branch <name> <sha>*' -- $out; and echo true; or echo false)

    set -e SWEEP_OPEN_PRS
    builtin cd $prev_pwd
end

# Open PRs cannot be listed: remote branches stay, local cleanup still runs.
begin
    reset_mocks
    set -l prev_pwd $PWD
    sweep_fixture
    set -gx SWEEP_PR_FAIL 1
    set -l out (git-sweep 2>&1)
    check "git-sweep: unlisted PRs exits 0" 0 $status
    check "git-sweep: unlisted PRs reported" true (string match -q '*Could not list open PRs*' -- $out; and echo true; or echo false)
    check "git-sweep: unlisted PRs keeps merged remote branches" true (has_remote r-merged)
    check "git-sweep: unlisted PRs still deletes merged local branches" false (has_local r-merged)
    set -e SWEEP_PR_FAIL
    builtin cd $prev_pwd
end

# Network drop: carries on offline against the last fetched state.
begin
    reset_mocks
    set -l prev_pwd $PWD
    sweep_fixture
    set -gx MOCK_GIT_FAIL_FETCH 1
    set -l out (git-sweep 2>&1)
    check "git-sweep: network drop exits 0" 0 $status
    check "git-sweep: network drop warns" true (string match -q '*fetch from*failed*' -- $out; and echo true; or echo false)
    reset_mocks
    check "git-sweep: network drop keeps remote branches" true (has_remote r-merged)
    check "git-sweep: network drop still deletes merged local branches" false (has_local r-merged)
    builtin cd $prev_pwd
end

# --force, --keep, and a dirty current branch.
begin
    reset_mocks
    set -l prev_pwd $PWD
    sweep_fixture
    git switch -q r-merged
    echo dirt >>base
    git-sweep --force --keep r-ff >/dev/null 2>&1
    check "git-sweep: -f exits 0" 0 $status
    check "git-sweep: -f deletes a gone branch with unmerged commits" false (has_local gone-unmerged)
    check "git-sweep: -f still keeps unmerged work whose remote exists" true (has_local wip)
    check "git-sweep: -f never deletes unmerged remote branches" true (has_remote wip)
    check "git-sweep: --keep protects the local branch" true (has_local r-ff)
    check "git-sweep: --keep protects the remote branch" true (has_remote r-ff)
    check "git-sweep: keeps a dirty current branch" true (has_local r-merged)
    check "git-sweep: stays on a dirty current branch" r-merged (git branch --show-current)
    git checkout -q -- base
    builtin cd $prev_pwd
end

# git-clean: deprecated, runs git-sweep --local-only.
begin
    reset_mocks
    set -l prev_pwd $PWD
    sweep_fixture
    set -l err (git-clean 2>&1 >/dev/null)
    check "git-clean: exits 0" 0 $status
    check "git-clean: prints a deprecation notice on stderr" true (string match -q '*deprecated*git-sweep*' -- $err; and echo true; or echo false)
    check "git-clean: deletes merged local branches" false (has_local r-squash)
    check "git-clean: never deletes remote branches" true (has_remote r-squash)
    check "git-clean: keeps a gone branch with unmerged commits" true (has_local gone-unmerged)
    git-clean -f >/dev/null 2>&1
    check "git-clean: -f deletes a gone branch with unmerged commits" false (has_local gone-unmerged)
    builtin cd $prev_pwd
end

functions -e _git_sweep_open_prs
source $repo_root/functions/_git_sweep_open_prs.fish

section "network isolation: git-sweep open-PR lookup"

check "_git_sweep_host: https" forge.test (_git_sweep_host https://forge.test/o/r.git)
check "_git_sweep_host: ssh with user and port" forge.test (_git_sweep_host ssh://git@Forge.Test:2222/o/r)
check "_git_sweep_host: scp-style" forge.test (_git_sweep_host git@forge.test:o/r.git)
_git_sweep_host /srv/git/r.git >/dev/null
check "_git_sweep_host: local path has no host" 1 $status

begin
    # Tokens are only handed out for the host they belong to.
    set -e GH_TOKEN GITHUB_TOKEN GITHUB_PERSONAL_ACCESS_TOKEN GH_ENTERPRISE_TOKEN GITHUB_ENTERPRISE_TOKEN GH_HOST
    set -e GITEA_TOKEN GITEA_ACCESS_TOKEN FORGEJO_TOKEN GITEA_HOST GITEA_URL GITEA_SERVER_URL FORGEJO_HOST
    set -e GITLAB_TOKEN GITLAB_PRIVATE_TOKEN GITLAB_ACCESS_TOKEN GITLAB_HOST GITLAB_URI GITLAB_URL
    set -gx GITEA_ACCESS_TOKEN gt
    _git_sweep_token gitea forge.test >/dev/null
    check "_git_sweep_token: gitea token without a host var is unused" 1 $status
    set -gx GITEA_HOST https://forge.test/
    check "_git_sweep_token: gitea token for its own host" gt (_git_sweep_token gitea forge.test)
    _git_sweep_token gitea other.test >/dev/null
    check "_git_sweep_token: gitea token withheld from another host" 1 $status
    set -gx GITHUB_TOKEN ht
    check "_git_sweep_token: github token for github.com" ht (_git_sweep_token github github.com)
    _git_sweep_token github ghe.test >/dev/null
    check "_git_sweep_token: github.com token withheld from GHE" 1 $status
    set -gx GITLAB_TOKEN lt
    check "_git_sweep_token: gitlab token defaults to gitlab.com" lt (_git_sweep_token gitlab gitlab.com)
    _git_sweep_token gitlab gitlab.forge.test >/dev/null
    check "_git_sweep_token: gitlab token withheld from self-hosted" 1 $status
end

begin
    reset_mocks
    set -gx MOCK_CURL_BODY '[{"head":{"ref":"refs/pull/3/head","label":"someone:feat/x"}}]'
    set -l names (_git_sweep_pr_page anon gitea forge.test o/r 1)
    check "_git_sweep_pr_page: list exits 0" 0 $status
    check "_git_sweep_pr_page: reads the branch from head.label" true (contains -- feat/x $names; and echo true; or echo false)
    set -gx MOCK_CURL_BODY '[{"source_branch":"mr-branch"}]'
    check "_git_sweep_pr_page: gitlab source_branch" mr-branch (_git_sweep_pr_page anon gitlab forge.test g/sub/r 1)
    set -gx MOCK_CURL_BODY '[]'
    set -l empty (_git_sweep_pr_page anon gitea forge.test o/r 1)
    check "_git_sweep_pr_page: empty page exits 0" 0 $status
    check "_git_sweep_pr_page: empty page prints nothing" 0 (count $empty)
    for body in '{"message":"Not Found"}' '<html>login</html>' ''
        set -gx MOCK_CURL_BODY $body
        _git_sweep_pr_page anon gitea forge.test o/r 1 >/dev/null
        check "_git_sweep_pr_page: rejects body '$body'" 1 $status
    end
    set -gx MOCK_CURL_BODY '[]'
    set -gx MOCK_CURL_STATUS 22
    _git_sweep_pr_page anon gitea forge.test o/r 1 >/dev/null
    check "_git_sweep_pr_page: HTTP error fails" 1 $status

    # The token travels on curl's stdin, never on its command line.
    reset_mocks
    set -gx MOCK_CURL_BODY '[]'
    set -gx MOCK_CURL_LOG (mktemp)
    set -ga TMPDIRS $MOCK_CURL_LOG
    set -gx GITEA_HOST forge.test
    set -gx GITEA_ACCESS_TOKEN secret-token-123
    _git_sweep_pr_page token gitea forge.test o/r 1 >/dev/null
    check "_git_sweep_pr_page: token request exits 0" 0 $status
    check "_git_sweep_pr_page: token kept off curl's argv" false (command grep -q secret-token-123 $MOCK_CURL_LOG; and echo true; or echo false)
    set -e GITEA_HOST GITEA_ACCESS_TOKEN GITHUB_TOKEN GITLAB_TOKEN
    reset_mocks
end

begin
    reset_mocks
    set -l prev_pwd $PWD
    builtin cd (new_repo)
    git remote add origin https://forge.test/o/r.git
    # Real CLIs must not reach the network from the test suite.
    function tea
        return 1
    end
    function gh
        return 1
    end
    function glab
        return 1
    end

    set -l pages $MOCK_DIR/sweep_pages.sh
    printf '%s\n' '#!/bin/sh' \
        'case "$*" in *page=1*) echo '"'"'[{"head":{"ref":"open-1","label":"open-1"}}]'"'"' ;; *) echo "[]" ;; esac' >$pages
    chmod +x $pages
    set -gx MOCK_CURL_HANDLER $pages
    set -l heads (_git_sweep_open_prs origin)
    check "_git_sweep_open_prs: falls back to curl and pages" 0 $status
    check "_git_sweep_open_prs: lists the open PR head" true (contains -- open-1 $heads; and echo true; or echo false)

    set -l endless $MOCK_DIR/sweep_endless.sh
    printf '%s\n' '#!/bin/sh' 'echo '"'"'[{"head":{"ref":"x","label":"x"}}]'"'"'' >$endless
    chmod +x $endless
    set -gx MOCK_CURL_HANDLER $endless
    _git_sweep_open_prs origin >/dev/null
    check "_git_sweep_open_prs: a listing that never ends fails" 1 $status

    reset_mocks
    set -gx MOCK_CURL_STATUS 7
    _git_sweep_open_prs origin >/dev/null
    check "_git_sweep_open_prs: every method failing fails" 1 $status

    functions -e tea gh glab
    reset_mocks
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
    done \
    "exec $real_git \"\$@\"" >$cfg_update_handler
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
echo init >$r_gh/file && git -C $r_gh add file && git -C $r_gh commit -q -m init
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
        done \
        "exec $real_git \"\$@\"" >$gh_ls_handler
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
