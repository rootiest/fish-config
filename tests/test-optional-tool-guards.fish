#!/usr/bin/env fish
# Copyright (C) 2026 Rootiest
# SPDX-License-Identifier: AGPL-3.0-or-later
#
# Regression coverage for #231: optional binaries are guarded with `type -q`.
#   - ssh falls back to the system ssh when TERM=xterm-kitty but kitten is
#     absent (containers, sudo -i, nested shells), instead of "command not found".
#   - Feature functions print a one-line stderr message naming the missing
#     tool and return 1 rather than surfacing a raw "command not found".
#   - _fzf_preview_file falls back to cat when bat is absent.
#
# Runs isolated (no `# MODE:` marker): its own `fish --no-config` process, and
# every case runs against a sandboxed PATH holding only stubs; no real network
# tool is ever called.

source (realpath (dirname (status filename)))/lib.fish
set -p fish_function_path $repo_root/functions

set -l sandbox (path resolve (mktemp -d))
set -l saved_path $PATH
set -l saved_term $TERM

# Empty PATH: none of kitten, fzf, curl, tmux, yt-dlp, bat resolve.
mkdir -p $sandbox/empty
# Stub PATH: a fake system ssh and a real cat (for the bat fallback).
mkdir -p $sandbox/stub
printf '#!/bin/sh\necho "STUB-SSH $*"\n' >$sandbox/stub/ssh
chmod +x $sandbox/stub/ssh
ln -s (command -s cat) $sandbox/stub/cat
# A fake kitten in its own dir, so a case can add it to PATH without any
# further commands (the sandboxed PATHs below hold no chmod/rm).
mkdir -p $sandbox/kitten
printf '#!/bin/sh\necho "STUB-KITTEN $*"\n' >$sandbox/kitten/kitten
chmod +x $sandbox/kitten/kitten
# parur checks for an AUR helper before fzf, so give it one.
mkdir -p $sandbox/aur
printf '#!/bin/sh\nexit 0\n' >$sandbox/aur/paru
chmod +x $sandbox/aur/paru

# ---- ssh -------------------------------------------------------------------
section "ssh: kitty TERM without kitten falls back to system ssh"

set -gx PATH $sandbox/stub
set -gx TERM xterm-kitty
check "no kitten: system ssh runs" "STUB-SSH user@host" (ssh user@host 2>&1)
ssh user@host >/dev/null 2>&1
check "no kitten: exit status is ssh's" 0 $status

set -gx PATH $sandbox/kitten $sandbox/stub
check "kitten present: kitten ssh still used" "STUB-KITTEN ssh user@host" (ssh user@host 2>&1)
set -gx PATH $sandbox/stub

set -gx TERM xterm-256color
check "non-kitty TERM: system ssh runs" "STUB-SSH user@host" (ssh user@host 2>&1)
set -gx TERM $saved_term

# ---- feature functions -----------------------------------------------------
section "missing tool: one-line stderr message, status 1"

set -gx PATH $sandbox/empty

# Usage: __probe_missing <label> <expected stderr> <command...>
function __probe_missing --argument-names label want
    set -l cmd $argv[3..-1]
    set -l err ($cmd 2>&1 >/dev/null)
    set -l st $status
    set -l out ($cmd 2>/dev/null)
    check "$label: names the missing tool" "$want" (string replace -ra '\e\[[0-9;]*m' '' -- $err | string join '')
    check "$label: returns 1" 1 $st
    check "$label: nothing on stdout" "" (string join '' $out)
end

__probe_missing hist "hist: fzf is not installed" hist
__probe_missing logs "logs: fzf is not installed" logs
set -gx PATH $sandbox/aur
__probe_missing parur "parur: fzf is not installed" parur
set -gx PATH $sandbox/empty
__probe_missing tmux-clean "tmux-clean: tmux is not installed" tmux-clean
__probe_missing gip "gip: curl is not installed" gip
__probe_missing gip4 "gip4: curl is not installed" gip4
__probe_missing gip6 "gip6: curl is not installed" gip6
__probe_missing "gi -l" "gi: curl is not installed" gi -l
__probe_missing "gi target" "gi: curl is not installed" gi -o python
__probe_missing yt-dlp "yt-dlp: yt-dlp is not installed" yt-dlp --version

# ---- _fzf_preview_file -----------------------------------------------------
section "_fzf_preview_file: falls back to cat without bat"

set -gx PATH $sandbox/stub
echo "plain text" >$sandbox/file.txt
check "no bat: file content still previewed" "plain text" (_fzf_preview_file $sandbox/file.txt 2>&1)

set -gx PATH $saved_path
functions -e __probe_missing
rm -rf $sandbox
report
