#!/usr/bin/env fish
# Copyright (C) 2026 Rootiest
# SPDX-License-Identifier: AGPL-3.0-or-later
#
# MODE: isolated
#
# fish-deps download integrity (#224): verified binary downloads and
# download-then-run installer scripts. curl is mocked, so nothing here
# touches the network.

source (realpath (dirname (status filename)))/lib.fish
set -p fish_function_path $repo_root/functions
set -gx TERM xterm-256color

set -g work (mktemp -d)
set -gx HOME $work/home
mkdir -p $HOME

# Mock curl: writes $_curl_body to the -o target (or stdout), or fails with
# $_curl_fail. Every URL requested is logged to $_curl_urls.
set -g _curl_body
set -g _curl_fail 0
set -g _curl_urls
function curl
    set -l out
    set -l url
    set -l i 1
    while test $i -le (count $argv)
        switch $argv[$i]
            case -o
                set i (math $i + 1)
                set out $argv[$i]
            case --proto
                set i (math $i + 1)
            case '-*'
            case '*'
                set url $argv[$i]
        end
        set i (math $i + 1)
    end
    set -ga _curl_urls $url
    test $_curl_fail -eq 0; or return 22
    if string match -q '*.AppImage' -- $url; and set -q _curl_appimage
        printf '%s' $_curl_appimage >$out
    else if test -n "$out"
        printf '%s' $_curl_body >$out
    else
        printf '%s' $_curl_body
    end
end

function sha_of --argument-names text
    printf '%s' $text | sha256sum | string split -f1 ' '
end

# =============================================================================
# 1. _fish_deps_fetch_verified
# =============================================================================
section _fish_deps_fetch_verified

set -g _curl_body payload
set -l dest $work/dl.bin
_fish_deps_fetch_verified https://example.test/a $dest (sha_of payload)
check "matching digest returns 0" 0 $status
check "matching digest keeps the file" true (test -f $dest; and echo true; or echo false)

_fish_deps_fetch_verified https://example.test/a $dest (sha_of payload | string upper)
check "digest comparison is case-insensitive" 0 $status

set -l err (_fish_deps_fetch_verified https://example.test/a $dest (sha_of tampered) 2>&1)
check "mismatched digest returns 1" 1 $status
check "mismatched digest removes the file" false (test -e $dest; and echo true; or echo false)
check "mismatch is reported" true (string match -q '*Checksum mismatch*' -- "$err"; and echo true; or echo false)

set -g _curl_fail 1
_fish_deps_fetch_verified https://example.test/a $dest (sha_of payload) 2>/dev/null
check "failed download returns 1" 1 $status
check "failed download leaves no file" false (test -e $dest; and echo true; or echo false)
set -g _curl_fail 0

set -g _curl_urls
_fish_deps_fetch_verified https://example.test/a $dest "" 2>/dev/null
check "empty digest is refused" 1 $status
check "empty digest never downloads" 0 (count $_curl_urls)

_fish_deps_fetch_verified https://example.test/a 2>/dev/null
check "missing arguments is a usage error" 2 $status

# =============================================================================
# 2. _fish_deps_run_script
# =============================================================================
section _fish_deps_run_script

set -l marker $work/ran
set -g _curl_body "echo \"\$@\" > $marker; exit 7"
_fish_deps_run_script https://example.test/install.sh sh --yes extra
check "script exit status is passed through" 7 $status
check "script receives its arguments" "--yes extra" (command cat $marker 2>/dev/null)

rm -f $marker
set -g _curl_fail 1
_fish_deps_run_script https://example.test/install.sh sh 2>/dev/null
check "failed download returns 1" 1 $status
check "failed download never runs the script" false (test -e $marker; and echo true; or echo false)
set -g _curl_fail 0

set -g _curl_body ""
_fish_deps_run_script https://example.test/install.sh sh 2>/dev/null
check "empty download returns 1" 1 $status

_fish_deps_run_script https://example.test/install.sh 2>/dev/null
check "missing shell is a usage error" 2 $status

# =============================================================================
# 3. _fish_deps_wakatime_binary
# =============================================================================
section _fish_deps_wakatime_binary

# The checksum file lists other assets only: install must abort before the
# zip is ever requested.
set -g _curl_urls
set -g _curl_body "0000000000000000000000000000000000000000000000000000000000000000  wakatime-cli-other.zip"
_fish_deps_wakatime_binary 2>/dev/null
check "no checksum entry returns 1" 1 $status
check "no checksum entry fetches only the checksum file" 1 (count $_curl_urls)
check "no checksum entry installs nothing" false (test -e $HOME/.config/wakatime/wakatime; and echo true; or echo false)

# =============================================================================
# 4. _fish_deps_marktext_appimage
# =============================================================================
section _fish_deps_marktext_appimage

if test (uname -m) = x86_64
    # A release whose AppImage asset has no digest is refused.
    set -g _curl_urls
    set -g _curl_body '{"assets":[{"name":"x.AppImage","uploader":{"login":"u"},"digest":null,"browser_download_url":"https://example.test/marktext-linux-1.0.AppImage"}]}'
    _fish_deps_marktext_appimage 2>/dev/null
    check "AppImage without a digest returns 1" 1 $status
    check "AppImage without a digest is never downloaded" 1 (count $_curl_urls)

    # A digest from a sibling asset must not be paired with the AppImage URL.
    set -g _curl_urls
    set -g _curl_body '{"assets":[{"digest":"sha256:'(sha_of other)'","browser_download_url":"https://example.test/marktext-linux-1.0.deb"},{"uploader":{"login":"u"},"digest":null,"browser_download_url":"https://example.test/marktext-linux-1.0.AppImage"}]}'
    _fish_deps_marktext_appimage 2>/dev/null
    check "sibling asset's digest is not borrowed" 1 $status

    # The happy path: the AppImage matching its own digest is installed.
    set -g _curl_appimage appimage-bytes
    set -g _curl_body '{"assets":[{"name":"m.AppImage","uploader":{"login":"u"},"size":1,"digest":"sha256:'(sha_of appimage-bytes)'","download_count":3,
"browser_download_url":"https://example.test/marktext-linux-1.0.AppImage"}]}'
    _fish_deps_marktext_appimage 2>/dev/null
    check "verified AppImage returns 0" 0 $status
    check "verified AppImage is installed executable" true (test -x $HOME/.local/bin/marktext; and echo true; or echo false)

    # Same release, tampered bytes: install fails, previous copy survives.
    set -g _curl_appimage tampered
    _fish_deps_marktext_appimage 2>/dev/null
    check "tampered AppImage returns 1" 1 $status
    check "tampered AppImage leaves the installed copy" appimage-bytes (command cat $HOME/.local/bin/marktext)
    set -e _curl_appimage
end

# =============================================================================
# 5. _fish_deps_update exit status (#228)
# =============================================================================
section _fish_deps_update

# PATH holds only stub tools, so no real tool can be touched. `cargo` fails
# for the lsd crate and succeeds for eza and bat; fisher is a stub function.
set -l stubs $work/stubs
mkdir -p $stubs
for t in eza lsd bat
    printf '#!/bin/sh\nexit 0\n' >$stubs/$t
    chmod +x $stubs/$t
end
printf '#!/bin/sh\ncase "$*" in *lsd*) exit 1;; esac\nexit 0\n' >$stubs/cargo
chmod +x $stubs/cargo

set -g _fisher_rc 0
function fisher
    return $_fisher_rc
end

set -l oldpath $PATH
set -gx PATH $stubs

set -l err (_fish_deps_update 2>&1 >/dev/null)
set -l rc $status
check "a failing update returns 1" 1 $rc
check "failure summary counts failed of attempted" true (string match -q '*1 of 4 updates failed*' -- "$err"; and echo true; or echo false)
check "failure summary names the failed tool" true (string match -q '*failed: *lsd*' -- "$err"; and echo true; or echo false)
check "successful tools are not named as failed" false (string match -q '*eza*' -- "$err"; and echo true; or echo false)

set -g _fisher_rc 1
set err (_fish_deps_update 2>&1 >/dev/null)
check "fisher failure is counted too" true (string match -q '*2 of 4 updates failed*' -- "$err"; and echo true; or echo false)
check "fisher failure is named" true (string match -q '*fisher*' -- "$err"; and echo true; or echo false)

fish-deps update >/dev/null 2>&1
check "fish-deps update propagates the failure" 1 $status

# Everything succeeding: cargo stub no longer rejects lsd.
printf '#!/bin/sh\nexit 0\n' >$stubs/cargo
set -g _fisher_rc 0
set err (_fish_deps_update 2>&1 >/dev/null)
check "all updates succeeding returns 0" 0 $status
check "all updates succeeding prints no stderr" "" "$err"
fish-deps update >/dev/null 2>&1
check "fish-deps update returns 0 on success" 0 $status

set -gx PATH $oldpath
functions -e fisher

# =============================================================================
# Cleanup
# =============================================================================
functions -e curl sha_of
command rm -rf $work
report
