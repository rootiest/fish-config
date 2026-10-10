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
# 4b. _fish_deps_release_tag (#300)
# =============================================================================
section _fish_deps_release_tag

# A throwaway repository with one empty commit and the given lightweight
# tags. Signing is switched off so the user's git config cannot interfere.
function mk_tag_repo --argument-names dir
    git init -q $dir
    git -C $dir -c user.name=t -c user.email=t@example.test -c commit.gpgsign=false commit -q --allow-empty -m init
    for t in $argv[2..]
        git -C $dir -c tag.gpgsign=false tag $t
    end
end

# Upstream's real mix: releases, a beta, pre-release numbering that sorts
# above a release as a string, and the historical markers.
mk_tag_repo $work/tags-mixed 3.7.1 4.0b1 4.9.2 4.9.3 4.10.0 4.10.0b1 LastC++03 official fish-1.0
check "the newest release wins, compared as versions not strings" 4.10.0 (_fish_deps_release_tag $work/tags-mixed)

_fish_deps_release_tag $work/tags-mixed >/dev/null
check "a release tag exits 0" 0 $status

mk_tag_repo $work/tags-pre 4.0b1 4.1b2 official LastC++03 fish-1.0
set -l got (_fish_deps_release_tag $work/tags-pre)
set -l rc $status
check "betas and markers are never picked" "" "$got"
check "no release tag exits 1" 1 $rc

mk_tag_repo $work/tags-none
_fish_deps_release_tag $work/tags-none >/dev/null
check "a repository with no tags exits 1" 1 $status

_fish_deps_release_tag $work/not-a-repo >/dev/null 2>&1
check "a directory that is not a repository exits 1" 1 $status

functions -e mk_tag_repo

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
printf '#!/bin/sh\necho "$*" >>%s\ncase "$*" in *lsd*) exit 1;; esac\nexit 0\n' $work/cargo-update.log >$stubs/cargo
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

# Crates are updated against the versions they were published with (#7).
check "update passes --locked to cargo" true (string match -q '*install --locked --force eza*' -- (command cat $work/cargo-update.log | string collect); and echo true; or echo false)
check "update never runs an unlocked cargo install" false (string match -qr '^install --force' -- (command cat $work/cargo-update.log); and echo true; or echo false)

# =============================================================================
# 6. _fish_deps_wakatime_binary without unzip (#8)
# =============================================================================
section _fish_deps_wakatime_binary / unzip

# PATH holds only a uname stub: no unzip, and nothing else to fall back on.
# The checksum lookup succeeds, so the unzip check is what stops the install,
# and it must do so before the zip is requested.
set -l nounzip $work/nounzip
mkdir -p $nounzip
printf '#!/bin/sh\necho x86_64\n' >$nounzip/uname
chmod +x $nounzip/uname

set -g _curl_urls
set -g _curl_body "0000000000000000000000000000000000000000000000000000000000000000  wakatime-cli-linux-amd64.zip"
set oldpath $PATH
set -gx PATH $nounzip
set err (_fish_deps_wakatime_binary 2>&1)
set rc $status
set -gx PATH $oldpath
check "missing unzip returns 1" 1 $rc
check "missing unzip says so" true (string match -q '*unzip is required*' -- "$err"; and echo true; or echo false)
check "missing unzip fetches only the checksum file" 1 (count $_curl_urls)

# =============================================================================
# 7. _fish_deps_is_arch (#3)
# =============================================================================
section _fish_deps_is_arch

function write_osrel
    printf '%s\n' $argv >$work/os-release
end
set -g __fish_deps_os_release $work/os-release

write_osrel 'NAME="Arch Linux"' ID=arch
_fish_deps_is_arch
check "ID=arch is Arch" 0 $status

write_osrel ID=cachyos 'ID_LIKE="arch"'
_fish_deps_is_arch
check "ID_LIKE=arch (CachyOS) is Arch" 0 $status

write_osrel ID=endeavouros 'ID_LIKE=arch'
_fish_deps_is_arch
check "unquoted ID_LIKE=arch is Arch" 0 $status

write_osrel ID=garuda 'ID_LIKE="arch archlinux"'
_fish_deps_is_arch
check "arch among several ID_LIKE words is Arch" 0 $status

write_osrel ID=ubuntu 'ID_LIKE=debian'
_fish_deps_is_arch
check "Ubuntu is not Arch" 1 $status

write_osrel ID=debian
_fish_deps_is_arch
check "Debian is not Arch" 1 $status

write_osrel ID=fedora 'ID_LIKE="rhel fedora"'
_fish_deps_is_arch
check "Fedora is not Arch" 1 $status

write_osrel ID=archaic
_fish_deps_is_arch
check "a name merely starting with arch is not Arch" 1 $status

set -g __fish_deps_os_release $work/no-such-os-release
_fish_deps_is_arch
check "an unreadable os-release is not Arch" 1 $status

# =============================================================================
# 7b. _fish_deps_detect_pm (#301)
# =============================================================================
section _fish_deps_detect_pm

# One directory of stub package-manager executables per scenario, and PATH
# set to just that directory, so the host's real managers are never seen.
# This config's own pkg function is on fish_function_path throughout: it is
# the thing that must not be mistaken for a package manager.
set -g _pm_root $work/detect
for combo in empty dnf zypper yum apt+dnf paru+apt pkg
    mkdir -p $_pm_root/$combo
    for name in (string split + -- $combo)
        test $name = empty; and continue
        printf '#!/bin/sh\nexit 0\n' >$_pm_root/$combo/$name
        chmod +x $_pm_root/$combo/$name
    end
end

check "the pkg function exists, so the checks below mean something" true (functions -q pkg; and echo true; or echo false)

set oldpath $PATH
set -gx PATH $_pm_root/empty
check "no package manager: nothing printed, despite the pkg function" "" (_fish_deps_detect_pm)
set -gx PATH $_pm_root/dnf
check "dnf alone is dnf, not the pkg function" dnf (_fish_deps_detect_pm)
set -gx PATH $_pm_root/zypper
check "zypper alone is zypper" zypper (_fish_deps_detect_pm)
set -gx PATH $_pm_root/yum
check "yum alone is yum" yum (_fish_deps_detect_pm)
set -gx PATH $_pm_root/apt+dnf
check "apt wins over dnf (priority order kept)" apt (_fish_deps_detect_pm)
set -gx PATH $_pm_root/paru+apt
check "paru wins over apt (priority order kept)" paru (_fish_deps_detect_pm)
set -gx PATH $_pm_root/pkg
check "a real pkg executable (FreeBSD) is still detected" pkg (_fish_deps_detect_pm)
set -gx PATH $oldpath
set -e _pm_root

# =============================================================================
# 8. _fish_deps_pm_pkg / _fish_deps_pm_has_pkg (#5, #6)
# =============================================================================
section _fish_deps_pm_pkg

check "apt spells go golang-go" golang-go (_fish_deps_pm_pkg apt go)
check "dnf spells go golang" golang (_fish_deps_pm_pkg dnf go)
check "pacman spells go go" go (_fish_deps_pm_pkg pacman go)
check "apt compiler is build-essential" build-essential (_fish_deps_pm_pkg apt cc)
check "pacman compiler is base-devel" base-devel (_fish_deps_pm_pkg pacman cc)
check "dnf compiler is gcc" gcc (_fish_deps_pm_pkg dnf cc)
check "an unmapped name passes through" ripgrep (_fish_deps_pm_pkg apt ripgrep)
_fish_deps_pm_pkg brew cc >/dev/null
check "a manager with no compiler package returns 1" 1 $status

section _fish_deps_pm_has_pkg

# apt-cache and pacman stubs: only the package called "known" exists.
set -l pmbin $work/pmbin
mkdir -p $pmbin
printf '#!/bin/sh\n[ "$2" = known ] && exit 0\nexit 100\n' >$pmbin/apt-cache
printf '#!/bin/sh\n[ "$2" = known ] && exit 0\nexit 1\n' >$pmbin/pacman
chmod +x $pmbin/apt-cache $pmbin/pacman
set oldpath $PATH
set -gx PATH $pmbin $oldpath

_fish_deps_pm_has_pkg apt known
check "apt knows a packaged name" 0 $status
_fish_deps_pm_has_pkg apt ov
check "apt does not know ov" 1 $status
_fish_deps_pm_has_pkg pacman known
check "pacman knows a packaged name" 0 $status
_fish_deps_pm_has_pkg pacman missing
check "pacman does not know a missing name" 1 $status
_fish_deps_pm_has_pkg dnf anything
check "a manager that cannot be queried is assumed to have it" 0 $status
_fish_deps_pm_has_pkg paru anything
check "an AUR helper is assumed to have it" 0 $status

set -gx PATH $oldpath

# =============================================================================
# 9. _fish_deps_ask (#9)
# =============================================================================
section _fish_deps_ask

set -e _fdc_cancelled
# Feeds ANSWER (printf %b escapes) on stdin, through a file so the function
# runs in this shell. An empty ANSWER is end of input, i.e. Ctrl+D.
function ask_with --argument-names answer
    printf '%b' "$answer" >$work/answer
    _fish_deps_ask "Go on?" <$work/answer >/dev/null 2>&1
end

ask_with 'y\n'
check "y accepts" 0 $status
ask_with 'Y\n'
check "Y accepts" 0 $status
ask_with 'yes\n'
check "yes accepts" 0 $status
ask_with '\n'
check "Enter accepts (the default)" 0 $status
ask_with 'n\n'
check "n declines this step" 1 $status
ask_with 'N\n'
check "N declines this step" 1 $status
ask_with 'q\n'
check "q quits" 2 $status
ask_with 'Q\n'
check "Q quits" 2 $status
ask_with ''
check "end of input (Ctrl+D) quits instead of defaulting to yes" 2 $status
ask_with 'maybe\ny\n'
check "an unrecognized answer is asked again" 0 $status

set -g _fdc_cancelled 1
ask_with 'y\n'
check "an earlier interrupt quits without asking" 2 $status
set -e _fdc_cancelled

functions -e ask_with

# =============================================================================
# 10. _fish_deps_refresh_path (#2)
# =============================================================================
section _fish_deps_refresh_path

# rustup lands in ~/.cargo/bin, `cargo install` in $CARGO_HOME/bin: both must
# be reachable afterwards, not just the first that exists.
set oldpath $PATH
set -g CARGO_HOME $work/cargohome
mkdir -p $CARGO_HOME/bin $HOME/.cargo/bin
# The AppImage test above created ~/.local/bin in the sandbox; remove it so
# there is a candidate directory that really is missing.
command rm -rf $HOME/.local
set -l missing $HOME/.local/bin

_fish_deps_refresh_path
check "refresh returns 0" 0 $status
check "CARGO_HOME/bin is on PATH" true (contains -- $CARGO_HOME/bin $PATH; and echo true; or echo false)
check "~/.cargo/bin is on PATH too" true (contains -- $HOME/.cargo/bin $PATH; and echo true; or echo false)
check "a directory that does not exist is not added" false (contains -- $missing $PATH; and echo true; or echo false)

set -l before (count $PATH)
_fish_deps_refresh_path
check "a second refresh adds nothing" $before (count $PATH)

set -gx PATH $oldpath
set -e CARGO_HOME

# =============================================================================
# 11. _fish_deps_ensure (#2, #5, #6, #8)
# =============================================================================
section _fish_deps_ensure

set -g _real_path $PATH

# The "package manager" is a stub apt plus a sudo function that records what
# it was asked to install and, instead of installing, appends the directory
# holding that tool's stub to PATH. Nothing real is installed.
set -g _ens_bin $work/ensure-bin
set -g _ens_pkgs $work/ensure-pkgs
mkdir -p $_ens_bin $_ens_pkgs/cc $_ens_pkgs/unzip $_ens_pkgs/go
printf '#!/bin/sh\nexit 0\n' >$_ens_bin/apt
printf '#!/bin/sh\nexit 0\n' >$_ens_pkgs/cc/cc
printf '#!/bin/sh\nexit 0\n' >$_ens_pkgs/unzip/unzip
mkdir -p $work/inst-logs
printf '#!/bin/sh\necho "$*" >>%s/go.log\nexit 0\n' $work/inst-logs >$_ens_pkgs/go/go
chmod +x $_ens_bin/apt $_ens_pkgs/cc/cc $_ens_pkgs/unzip/unzip $_ens_pkgs/go/go

set -g _sudo_log
function sudo
    set -ga _sudo_log "$argv"
    switch "$argv"
        case 'apt install -y build-essential'
            set -gx PATH $PATH $_ens_pkgs/cc
        case 'apt install -y unzip'
            set -gx PATH $PATH $_ens_pkgs/unzip
        case 'apt install -y golang-go'
            set -gx PATH $PATH $_ens_pkgs/go
    end
end

# Answers come from $_ask_answers, one per prompt (y, n or q); running out is
# a quit, so an unexpected extra prompt shows up as a failure.
set -g _ask_answers
set -g _ask_log
function _fish_deps_ask
    set -ga _ask_log "$argv[1]"
    set -l ans $_ask_answers[1]
    set -e _ask_answers[1]
    switch "$ans"
        case y
            return 0
        case n
            return 1
    end
    return 2
end

function ens_reset
    set -gx PATH $_real_path
    set -e _fdc_ensure_cc _fdc_ensure_toolchain _fdc_ensure_unzip _fdc_ensure_go
    set -g _sudo_log
    set -g _ask_log
    set -g _ask_answers $argv
    set -gx PATH $_ens_bin
end

set oldpath $PATH

ens_reset n
_fish_deps_ensure cc
check "cc missing, declined: returns 1" 1 $status
check "cc missing, declined: nothing is installed" 0 (count $_sudo_log)

ens_reset y
_fish_deps_ensure cc
check "cc missing, accepted: returns 0" 0 $status
check "cc is installed through the package manager" "apt install -y build-essential" "$_sudo_log"
check "cc is found afterwards" true (command -q cc; and echo true; or echo false)
check "the question named the package" true (string match -q '*build-essential*' -- "$_ask_log"; and echo true; or echo false)
_fish_deps_ensure cc
check "an answered need is not asked again" 0 $status
check "an answered need prompts once" 1 (count $_ask_log)

ens_reset n
_fish_deps_ensure unzip
check "unzip declined returns 1" 1 $status
_fish_deps_ensure unzip
check "a declined need is remembered" 1 $status
check "a declined need prompts once" 1 (count $_ask_log)
check "a declined need installs nothing" 0 (count $_sudo_log)

ens_reset q
_fish_deps_ensure go
check "quitting at the prompt returns 130" 130 $status
check "a quit is not remembered as a decline" false (set -q _fdc_ensure_go; and echo true; or echo false)

ens_reset y
_fish_deps_ensure go
check "go accepted returns 0" 0 $status
check "go is installed as golang-go under apt" "apt install -y golang-go" "$_sudo_log"

# No package manager at all: manual instructions, and no prompt. PATH holds
# nothing, and the real detect_pm must not take this config's pkg function
# for one (#301).
ens_reset y
mkdir -p $work/no-pm-bin
set -gx PATH $work/no-pm-bin
_fish_deps_ensure unzip >$work/out 2>&1
check "no package manager returns 1" 1 $status
check "no package manager prompts nothing" 0 (count $_ask_log)
check "no package manager prints how to fix it" true (string match -q '*install the unzip package*' -- (string collect <$work/out); and echo true; or echo false)

ens_reset
_fish_deps_ensure nonsense
check "an unknown need is a usage error" 2 $status

# A rustup shim with no default toolchain: cargo exists but cannot run.
set -gx PATH $_real_path
set -g _rustup_stub $work/rustup-stub
mkdir -p $_rustup_stub
printf '#!/bin/sh\n[ -e %s ] && exit 0\necho "rustup could not choose a version of cargo" >&2\nexit 1\n' $work/toolchain-ready >$_rustup_stub/cargo
printf '#!/bin/sh\necho "$*" >>%s\n: >%s\nexit 0\n' $work/rustup.log $work/toolchain-ready >$_rustup_stub/rustup
chmod +x $_rustup_stub/cargo $_rustup_stub/rustup

command rm -f $work/toolchain-ready $work/rustup.log
ens_reset y
set -gx PATH $_rustup_stub $_ens_bin
_fish_deps_ensure toolchain
check "toolchain accepted returns 0" 0 $status
check "the toolchain comes from rustup default stable" "default stable" (string collect <$work/rustup.log)

set -gx PATH $_real_path
command rm -f $work/toolchain-ready $work/rustup.log
ens_reset n
set -gx PATH $_rustup_stub $_ens_bin
_fish_deps_ensure toolchain
check "toolchain declined returns 1" 1 $status
check "toolchain declined runs no rustup" false (test -e $work/rustup.log; and echo true; or echo false)

# `cargo` is toolchain, then compiler: a working toolchain still needs cc.
ens_reset n
set -gx PATH $_rustup_stub $_ens_bin
: >$work/toolchain-ready
_fish_deps_ensure cargo
check "cargo without a compiler (declined) returns 1" 1 $status
ens_reset y
set -gx PATH $_rustup_stub $_ens_bin
_fish_deps_ensure cargo
check "cargo with a compiler installed on request returns 0" 0 $status
check "cargo's compiler comes from the package manager" "apt install -y build-essential" "$_sudo_log"

set -gx PATH $oldpath

# =============================================================================
# 12. _fish_deps_install end to end (#1-#10)
# =============================================================================
section _fish_deps_install

# Every Required/Recommended/Integration tool is a stub on PATH except the
# ones a scenario removes, so only those are offered. cargo, go and the rest
# only record how they were called. `fish-deps install` is driven by the
# scripted _fish_deps_ask above plus a stdin file for the method menu.
set -g _inst_bin $work/inst-bin
set -g _inst_all uv cargo fish starship fzf zoxide direnv eza lsd bat ov rg trash python3 wakatime tailscale cc cat head

function inst_reset --argument-names missing
    set -gx PATH $_real_path
    command rm -rf $_inst_bin $work/inst-logs $work/cargo_fail
    mkdir -p $_inst_bin $work/inst-logs
    for t in $_inst_all
        contains -- $t (string split ' ' -- $missing); and continue
        switch $t
            case fish
                printf '#!/bin/sh\nread v <%s\necho "fish, version $v"\n' $work/fishver >$_inst_bin/$t
            case cat
                printf '#!/bin/sh\nexit 0\n' >$_inst_bin/$t
            case '*'
                printf '#!/bin/sh\necho "$*" >>%s/%s.log\n[ -e %s ] && [ "$1 $2" = "install --locked" ] && exit 1\nexit 0\n' $work/inst-logs $t $work/cargo_fail >$_inst_bin/$t
        end
        chmod +x $_inst_bin/$t
    end
    # apt exists and packages only what the scenario lists in aptknown.
    printf '#!/bin/sh\nexit 0\n' >$_inst_bin/apt
    printf '#!/bin/sh\nwhile read l; do [ "$l" = "$2" ] && exit 0; done <%s\nexit 100\n' $work/aptknown >$_inst_bin/apt-cache
    chmod +x $_inst_bin/apt $_inst_bin/apt-cache
    printf '%s\n' starship zoxide fish wakatime direnv >$work/aptknown
    echo 4.9.3 >$work/fishver
    printf '%s\n' 'ID=ubuntu' 'ID_LIKE=debian' >$work/os-release
    set -g __fish_deps_os_release $work/os-release
    set -g _sudo_log
    set -gx PATH $_inst_bin
end

# Runs the installer with scripted answers (comma separated) and stdin text.
function inst_run --argument-names answers input
    set -g _ask_answers (string split , -- $answers)
    set -g _ask_log
    printf '%b' "$input" >$work/stdin
    _fish_deps_install <$work/stdin >$work/out 2>&1
    set -g _inst_rc $status
    set -g _inst_out (string collect <$work/out)
end

function inst_log --argument-names tool
    test -e $work/inst-logs/$tool.log; and string collect <$work/inst-logs/$tool.log
end

function inst_saw --argument-names needle haystack
    string match -q "*$needle*" -- "$haystack"; and echo true; or echo false
end

# ---- q at the first prompt ----------------------------------------------
inst_reset "starship zoxide"
inst_run q ''
check "q at the first prompt exits 130" 130 $_inst_rc
check "q at the first prompt asks exactly once" 1 (count $_ask_log)
check "q at the first prompt installs nothing" false (inst_saw install (inst_log cargo))
check "a cancelled run says so" true (inst_saw "Installation cancelled" "$_inst_out")
check "a cancelled run removes its signal handler" false (functions -q __fdi_on_sigint; and echo true; or echo false)
check "a cancelled run leaves no cancellation state behind" false (set -q _fdc_cancelled; and echo true; or echo false)

# ---- a crate install is --locked, then q stops the run -------------------
inst_reset "starship zoxide"
inst_run y,q '1\n'
check "q after one install exits 130" 130 $_inst_rc
check "the first crate is installed --locked" true (inst_saw "install --locked starship" (inst_log cargo))
check "nothing is installed after q" false (inst_saw zoxide (inst_log cargo))
check "the run asked about starship then zoxide" 2 (count $_ask_log)

# ---- Ctrl+D / q at the method menu ---------------------------------------
inst_reset starship
inst_run y ''
check "Ctrl+D at the method menu exits 130, not the default method" 130 $_inst_rc
check "Ctrl+D at the method menu installs nothing" false (inst_saw install (inst_log cargo))

inst_reset starship
inst_run y 'q\n'
check "q at the method menu exits 130" 130 $_inst_rc
check "q at the method menu installs nothing" false (inst_saw install (inst_log cargo))

# ---- success and failure reporting ---------------------------------------
inst_reset starship
inst_run y '1\n'
check "a good install exits 0" 0 $_inst_rc
check "a good install says installed" true (inst_saw "starship installed." "$_inst_out")

inst_reset starship
: >$work/cargo_fail
inst_run y '1\n'
check "a failed install exits 1" 1 $_inst_rc
check "a failed install says so" true (inst_saw "starship install failed." "$_inst_out")
check "a failed install is not reported as cancelled" false (inst_saw "cancelled" "$_inst_out")

# ---- the fish upgrade message (#10) ---------------------------------------
function _fish_deps_build_fish
    return 0
end
inst_reset ""
echo 3.7.1 >$work/fishver
inst_run y '1\n'
check "an upgrade exits 0" 0 $_inst_rc
check "the upgrade message is 'fish upgraded.'" true (inst_saw "fish upgraded." "$_inst_out")
check "the upgrade message has no 'upgradeed'" false (inst_saw upgradeed "$_inst_out")
functions -e _fish_deps_build_fish

# ---- AUR helpers only on Arch (#3) -----------------------------------------
inst_reset ""
inst_run '' ''
check "off Arch, paru and yay are never asked about" 0 (count $_ask_log)
check "off Arch, nothing missing means nothing to install" true (inst_saw "Nothing to install." "$_inst_out")

inst_reset ""
echo yay >>$work/aptknown
printf '%s\n' ID=cachyos 'ID_LIKE=arch' >$work/os-release
inst_run n ''
check "on Arch, yay is offered" true (contains -- "Install yay?" $_ask_log; and echo true; or echo false)

# ---- Go for ov (#6) ---------------------------------------------------------
inst_reset ov
inst_run y,y ''
check "ov with no package and no go exits 0" 0 $_inst_rc
check "go is installed first, through apt" "apt install -y golang-go" "$_sudo_log"
check "ov is then installed with go install" true (inst_saw "install github.com/noborus/ov@latest" (inst_log go))
check "the go prompt was asked after the ov prompt" 2 (count $_ask_log)

inst_reset ov
inst_run y,n ''
check "declining go fails the ov install" 1 $_inst_rc
check "declining go runs no go install" false (test -e $work/inst-logs/go.log; and echo true; or echo false)

# ---- unzip for wakatime (#8) -------------------------------------------------
function _fish_deps_wakatime_binary
    echo called >>$work/inst-logs/wakatime-binary.log
    return 0
end

inst_reset wakatime
inst_run y,y '1\n'
check "wakatime exits 0" 0 $_inst_rc
check "unzip is installed first" "apt install -y unzip" "$_sudo_log"
check "the wakatime download then runs" true (test -e $work/inst-logs/wakatime-binary.log; and echo true; or echo false)

inst_reset wakatime
inst_run y,n '1\n'
check "declining unzip fails the wakatime install" 1 $_inst_rc
check "declining unzip never starts the download" false (test -e $work/inst-logs/wakatime-binary.log; and echo true; or echo false)
functions -e _fish_deps_wakatime_binary

# ---- a C compiler for cargo (#5) ---------------------------------------------
inst_reset "starship cc"
inst_run y,y '1\n'
check "a missing compiler is installed on request" "apt install -y build-essential" "$_sudo_log"
check "the crate is built after the compiler is installed" true (inst_saw "install --locked starship" (inst_log cargo))
check "a missing compiler does not fail the install" 0 $_inst_rc

inst_reset "starship cc"
inst_run y,n '1\n'
check "declining the compiler fails the install" 1 $_inst_rc
check "declining the compiler never calls cargo install" false (inst_saw install (inst_log cargo))

# ---- fish-deps sync does not update after a cancel ---------------------------
function _fish_deps_update
    echo called >>$work/inst-logs/update.log
    return 0
end

inst_reset starship
set -g _ask_answers q
set -g _ask_log
printf '' >$work/stdin
fish-deps sync <$work/stdin >$work/out 2>&1
check "sync exits 130 when the install half is cancelled" 130 $status
check "sync does not update after a cancel" false (test -e $work/inst-logs/update.log; and echo true; or echo false)

inst_reset starship
set -g _ask_answers n
fish-deps sync <$work/stdin >$work/out 2>&1
check "sync exits 0 when everything was merely declined" 0 $status
check "sync updates after a completed install" true (test -e $work/inst-logs/update.log; and echo true; or echo false)
functions -e _fish_deps_update

set -gx PATH $oldpath
set -e __fish_deps_os_release
functions -e sudo _fish_deps_ask ens_reset inst_reset inst_run inst_log inst_saw write_osrel

# =============================================================================
# Cleanup
# =============================================================================
functions -e curl sha_of
command rm -rf $work
report
