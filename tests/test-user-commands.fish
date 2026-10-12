#!/usr/bin/env fish
# Copyright (C) 2026 Rootiest
# SPDX-License-Identifier: AGPL-3.0-or-later
#
# Coverage for a group of user-facing commands that are thin shells around
# an external binary: claude-docs and claude-pr (claude), sbver (sudo
# sbctl), steam-dl (systemd-inhibit + steam) and swapstat (sysctl, zramctl,
# swapon). Each is checked for its help flag, its argument validation, its
# missing-dependency path where it has one, and its core behavior: the exact
# command line it hands the binary, the output it builds from canned binary
# output, and whether the binary's exit status reaches the caller.
#
# Runs isolated (no `# MODE:` marker): every binary is a stub script in a
# mktemp -d directory, and $PATH is rebuilt from those stubs plus a handful
# of symlinked coreutils, so the real claude, sudo, sbctl or steam can never
# be reached -- claude-pr in particular must never push or open a real PR.
# `claude` is itself a C1 shadow in this config (see test-claude-wrapper):
# C1 is disabled here so the wrapper skips agents-init and agents-vault and
# just execs the stub. NO_COLOR is set so output compares as plain text.

source (realpath (dirname (status filename)))/lib.fish
set -p fish_function_path $repo_root/functions
source $repo_root/conf.d/__fish_config_op_registry.fish
set -g __fish_config_op_aliases 0
set -gx NO_COLOR 1

set -g tmp (mktemp -d)
set -gx STUB_LOG $tmp/log

# Coreutils the stubs and the functions under test need, with nothing else
# from the real $PATH, so `type -q sbctl` and friends see only our stubs.
mkdir $tmp/sys
for tool in sh env cat grep sed awk rm mkdir chmod
    ln -s (command -s $tool) $tmp/sys/$tool
end

# One directory per stub, so a case can leave any of them off $PATH. Each
# stub appends "name: args" to $STUB_LOG and exits with $<NAME>_STATUS.
function _stub --argument-names name
    mkdir -p $tmp/stub/$name
    set -l var (string upper -- (string replace -a - _ -- $name))_STATUS
    printf '%s\n' '#!/bin/sh' "echo \"$name: \$*\" >>\"\$STUB_LOG\"" \
        $argv[2..] "exit \${$var:-0}" >$tmp/stub/$name/$name
    chmod +x $tmp/stub/$name/$name
end

# Sets $PATH to the core tools plus the named stubs only.
function _path
    set -gx PATH $tmp/stub/$argv $tmp/sys
    rm -f $STUB_LOG
end

function _log
    cat $STUB_LOG 2>/dev/null
end

_stub claude
_stub sudo 'command "$@"' 'exit $?'
_stub sbctl 'printf "%s\n" "✓ /boot/EFI/a.efi is signed" "✗ /boot/EFI/b.efi is not signed" "/boot/x: invalid PE header" "note line"'
_stub systemd-inhibit 'shift 3; "$@"' 'exit $?'
_stub steam
_stub sysctl 'echo 60'
_stub zramctl 'case "$*" in *DATA,TOTAL*) echo "${ZDATA-4096 1024}" ;; *) printf "%s\n" "NAME ALGORITHM" "/dev/zram0 zstd" ;; esac'
_stub swapon 'printf "%s\n" "NAME TYPE PRIO" "/dev/zram0 partition 100"'

# ── claude-docs / claude-pr ──────────────────────────────────────────────
for fn in claude-docs claude-pr
    section "$fn"
    _path claude

    set -l out ($fn --help 2>&1)
    check "$fn --help exits 0" 0 $status
    check "$fn --help prints usage" true (string match -q "*$fn*" -- "$out"; and echo true; or echo false)
    check "$fn --help never runs claude" "" (_log)

    set -l err ($fn --oops 2>&1 >/dev/null)
    check "$fn with an argument exits 2" 2 $status
    check "$fn names the bad argument on stderr" true \
        (string match -q "*unexpected argument '--oops'*" -- "$err"; and echo true; or echo false)
    check "$fn with an argument never runs claude" "" (_log)

    $fn >/dev/null
    check "$fn exits 0 when claude does" 0 $status
    set -l calls (_log)
    check "$fn runs claude exactly once" 1 (count $calls)
    check "$fn passes the prompt as a single argument (no flags)" true \
        (string match -qr '^claude: \S' -- "$calls[1]"; and not string match -q 'claude: -*' -- "$calls[1]"; and echo true; or echo false)

    _path claude
    set -lx CLAUDE_STATUS 7
    $fn >/dev/null
    check "$fn propagates claude's exit status" 7 $status
    set -e CLAUDE_STATUS
end

_path claude
claude-docs >/dev/null
check "claude-docs prompt targets README.md" true \
    (string match -q '*update the README.md*' -- (_log); and echo true; or echo false)

_path claude
claude-pr >/dev/null
set -l pr_prompt (_log)
for want in 'Create a new git branch (kebab-case)' 'Conventional Commit' 'Push to remote' \
    "Create a PR to 'main'" 'Manual Verification' '- [ ]'
    check "claude-pr prompt includes '$want'" true \
        (string match -q -- "*$want*" "$pr_prompt"; and echo true; or echo false)
end

# ── sbver ────────────────────────────────────────────────────────────────
section sbver
_path sudo sbctl

sbver --help >/dev/null 2>&1
check "sbver --help exits 0" 0 $status
check "sbver --help runs nothing" "" (_log)

set -l err (sbver --bogus 2>&1 >/dev/null)
check "sbver with an unknown argument exits 2" 2 $status
check "sbver names the bad argument on stderr" true \
    (string match -q "*unexpected argument '--bogus'*" -- "$err"; and echo true; or echo false)
sbver --brief extra >/dev/null 2>&1
check "sbver --brief plus another argument exits 2" 2 $status
check "sbver usage errors never run sbctl" "" (_log)

_path sudo
set -l err (sbver 2>&1 >/dev/null)
check "sbver without sbctl exits 1" 1 $status
check "sbver without sbctl explains why on stderr" "sbver: sbctl is not installed" "$err"
check "sbver without sbctl never calls sudo" "" (_log)

_path sudo sbctl
set -l out (sbver)
check "sbver exits 1 when an image is unsigned" 1 $status
check "sbver runs sbctl verify through sudo" "sudo: sbctl verify" (_log)[1]
check "sbver prints the verified line" true (contains -- "✓ /boot/EFI/a.efi is signed" $out; and echo true; or echo false)
check "sbver prints the unsigned line" true (contains -- "✗ /boot/EFI/b.efi is not signed" $out; and echo true; or echo false)
check "sbver passes other lines through" true (contains -- "note line" $out; and echo true; or echo false)
check "sbver filters invalid PE header noise" false \
    (string match -q '*invalid PE header*' -- $out; and echo true; or echo false)
check "sbver summary counts failures and passes" "❌ Some images are not signed (1 failed, 1 passed)" $out[-1]

_path sudo sbctl
set -l out (sbver --brief)
check "sbver --brief hides per-file lines" false (contains -- "note line" $out; and echo true; or echo false)
check "sbver --brief still prints the summary" "❌ Some images are not signed (1 failed, 1 passed)" $out[-1]

# All-signed run: an sbctl that only reports passes.
_stub sbctl 'printf "%s\n" "✓ /boot/EFI/a.efi is signed" "✓ /boot/EFI/c.efi is signed"'
_path sudo sbctl
set -l out (sbver --brief)
check "sbver exits 0 when every image is signed" 0 $status
check "sbver all-signed summary" "✅ All images are signed (2 verified)" $out[-1]

# Nothing verified (sudo refused, or sbctl tracks nothing) is not a pass.
_stub sbctl
_path sudo sbctl
set -l out (sbver --brief)
check "sbver exits 1 when nothing was verified" 1 $status
check "sbver says nothing was verified" "❌ No images were verified" $out[-1]

# ── steam-dl ─────────────────────────────────────────────────────────────
section steam-dl
_path systemd-inhibit steam

steam-dl --help >/dev/null 2>&1
check "steam-dl --help exits 0" 0 $status
check "steam-dl --help launches nothing" "" (_log)

steam-dl now >/dev/null 2>&1
check "steam-dl with an argument exits 2" 2 $status
check "steam-dl with an argument launches nothing" "" (_log)

for missing in systemd-inhibit steam
    set -l present (string match -v -- $missing systemd-inhibit steam)
    _path $present
    set -l err (steam-dl 2>&1 >/dev/null)
    check "steam-dl without $missing exits 1" 1 $status
    check "steam-dl without $missing says so on stderr" "Error: $missing is not installed." "$err"
    check "steam-dl without $missing launches nothing" "" (_log)
end

_path systemd-inhibit steam
set -l out (steam-dl)
check "steam-dl exits 0 when steam does" 0 $status
check "steam-dl announces the inhibit" "Inhibiting sleep while Steam downloads..." "$out"
check "steam-dl wraps steam in systemd-inhibit idle:sleep" \
    "systemd-inhibit: --why=Active Download --who=User --what=idle:sleep steam" (_log)[1]
check "steam-dl actually launches steam" "steam: " (_log)[2]

_path systemd-inhibit steam
set -lx STEAM_STATUS 3
steam-dl >/dev/null
check "steam-dl propagates steam's exit status" 3 $status
set -e STEAM_STATUS

# ── swapstat ─────────────────────────────────────────────────────────────
section swapstat
_path sysctl zramctl swapon

swapstat --help >/dev/null 2>&1
check "swapstat --help exits 0" 0 $status
check "swapstat --help runs nothing" "" (_log)

swapstat -v >/dev/null 2>&1
check "swapstat with an argument exits 2" 2 $status
check "swapstat with an argument runs nothing" "" (_log)

set -l out (swapstat)
check "swapstat exits 0" 0 $status
check "swapstat reads vm.swappiness" true (contains -- "sysctl: -n vm.swappiness" (_log); and echo true; or echo false)
check "swapstat prints the report title" "── Memory & zRAM Report ──" $out[1]
check "swapstat computes the compression ratio" true (contains -- "Compression Ratio: 4:1" $out; and echo true; or echo false)
check "swapstat prints swappiness" true (contains -- "Kernel Swappiness: 60" $out; and echo true; or echo false)
check "swapstat prints the zramctl table" true (contains -- "/dev/zram0 zstd" $out; and echo true; or echo false)
check "swapstat prints the swapon table" true (contains -- "/dev/zram0 partition 100" $out; and echo true; or echo false)

_path sysctl zramctl swapon
set -lx ZDATA "3000 1024"
set -l out (swapstat)
check "swapstat rounds the ratio to two places" true (contains -- "Compression Ratio: 2.93:1" $out; and echo true; or echo false)

set -lx ZDATA "4096 0"
set -l out (swapstat)
check "swapstat skips the ratio when nothing is compressed" false \
    (string match -q 'Compression Ratio*' -- $out; and echo true; or echo false)

set -lx ZDATA ""
set -l out (swapstat)
check "swapstat skips the ratio without a zram0 device" false \
    (string match -q 'Compression Ratio*' -- $out; and echo true; or echo false)
check "swapstat still reports swappiness without zram0" true \
    (contains -- "Kernel Swappiness: 60" $out; and echo true; or echo false)
set -e ZDATA

# Each missing tool is reported and its sections skipped, not a raw
# "Unknown command" with exit 0 (#315).
for missing in sysctl zramctl swapon
    _path (string match -v -- $missing sysctl zramctl swapon)
    set -l err (swapstat 2>&1 >/dev/null)
    check "swapstat without $missing exits 1" 1 $status
    check "swapstat without $missing says so on stderr" true \
        (string match -q "swapstat: $missing is not installed*" -- "$err"; and echo true; or echo false)
end
_path zramctl swapon
set -l out (swapstat 2>/dev/null)
check "swapstat without sysctl still prints the zramctl table" true (contains -- "/dev/zram0 zstd" $out; and echo true; or echo false)
check "swapstat without sysctl skips swappiness" false \
    (string match -q 'Kernel Swappiness*' -- $out; and echo true; or echo false)

rm -rf $tmp
report
