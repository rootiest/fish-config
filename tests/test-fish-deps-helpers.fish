#!/usr/bin/env fish
# Copyright (C) 2026 Rootiest
# SPDX-License-Identifier: AGPL-3.0-or-later
#
# MODE: isolated
#
# fish-deps helpers not covered by tests/test-fish-deps.fish (#238): the
# dependency catalog, the package-manager install/upgrade dispatchers, the
# status report, and the pinned win32yank installer.
#
# The point of the pm_* cases is exit-status propagation. Every package
# manager (and sudo) is a stub script on a mktemp PATH that records its argv
# and exits with $FAKE_PM_RC, and PATH holds nothing else, so no real package
# manager or sudo can ever run. A failing install must surface as non-zero:
# a dispatcher that ends on an untaken branch reports 0 (the fish false-zero,
# AGENTS.md), and fish-deps would then claim the package was installed.

source (realpath (dirname (status filename)))/lib.fish
set -p fish_function_path $repo_root/functions
set -gx TERM xterm-256color

set -g work (mktemp -d)
set -gx HOME $work/home
mkdir -p $HOME
set -g _real_path $PATH

# One stub directory per package manager, each also holding a sudo that logs
# itself and then execs the rest of its argv (resolving against the same
# stub-only PATH). Every call lands in $_pm_log as one line.
set -g _pm_log $work/pm.log
set -gx FAKE_PM_RC 0
function mk_pm_dir --argument-names pm
    set -lx PATH $_real_path
    set -l dir $work/pm/$pm
    mkdir -p $dir
    printf '#!/bin/sh\necho "%s $*" >>%s\nexit ${FAKE_PM_RC:-0}\n' $pm $_pm_log >$dir/$pm
    printf '#!/bin/sh\necho "sudo $*" >>%s\nexec "$@"\n' $_pm_log >$dir/sudo
    chmod +x $dir/$pm $dir/sudo
    echo $dir
end

function pm_log
    test -s $_pm_log; and string join ' | ' <$_pm_log
    echo -n >$_pm_log
end

# =============================================================================
# 1. _fish_deps_catalog
# =============================================================================
section _fish_deps_catalog

_fish_deps_catalog
set -l n (count $_fdc_bins)
check "catalog is non-empty" true (test $n -gt 0; and echo true; or echo false)
check "_fdc_tiers is parallel to _fdc_bins" $n (count $_fdc_tiers)
check "_fdc_cargo is parallel to _fdc_bins" $n (count $_fdc_cargo)
check "_fdc_pm is parallel to _fdc_bins" $n (count $_fdc_pm)
check "_fdc_special is parallel to _fdc_bins" $n (count $_fdc_special)

set -l bad_tiers
for t in $_fdc_tiers
    contains -- $t req rec opt term int; or set -a bad_tiers $t
end
check "every tier is one of req/rec/opt/term/int" "" "$bad_tiers"
check "binary names are unique" $n (count (printf '%s\n' $_fdc_bins | sort -u))

function tier_of --argument-names bin
    set -l i (contains -i -- $bin $_fdc_bins); or return 1
    echo $_fdc_tiers[$i]
end
check "fish is required" req (tier_of fish)
check "fzf is required" req (tier_of fzf)
check "kitty is a terminal emulator" term (tier_of kitty)
check "wakatime is an integration" int (tier_of wakatime)
set -l i (contains -i -- rg $_fdc_bins)
check "rg installs from the ripgrep crate" ripgrep $_fdc_cargo[$i]
check "rg installs from the ripgrep package" ripgrep $_fdc_pm[$i]
set i (contains -i -- win32yank.exe $_fdc_bins)
check "win32yank uses its pinned-release installer" win32yank-release $_fdc_special[$i]

# =============================================================================
# 2. _fish_deps_pm_install
# =============================================================================
section _fish_deps_pm_install

mkdir -p $work/pm/empty
set -gx PATH $work/pm/empty
set -l err (_fish_deps_pm_install ripgrep 2>&1)
check "no package manager returns 1" 1 $status
check "no package manager is reported" true (string match -q '*No supported package manager*' -- "$err"; and echo true; or echo false)

# Expected argv per manager: sudo-wrapped where the manager needs root.
set -l cases \
    "paru|paru -S --noconfirm ripgrep" \
    "yay|yay -S --noconfirm ripgrep" \
    "pacman|sudo pacman -S --noconfirm ripgrep | pacman -S --noconfirm ripgrep" \
    "apt|sudo apt install -y ripgrep | apt install -y ripgrep" \
    "brew|brew install ripgrep" \
    "pkg|sudo pkg install -y ripgrep | pkg install -y ripgrep" \
    "dnf|sudo dnf install -y ripgrep | dnf install -y ripgrep" \
    "zypper|sudo zypper --non-interactive install ripgrep | zypper --non-interactive install ripgrep" \
    "yum|sudo yum install -y ripgrep | yum install -y ripgrep"
for c in $cases
    set -l pm (string split -m1 '|' -- $c)[1]
    set -l want (string split -m1 '|' -- $c)[2]
    set -gx PATH (mk_pm_dir $pm)
    pm_log >/dev/null

    set -gx FAKE_PM_RC 0
    _fish_deps_pm_install ripgrep >/dev/null 2>&1
    check "$pm: success returns 0" 0 $status
    check "$pm: runs the expected command" $want (pm_log)

    set -gx FAKE_PM_RC 1
    _fish_deps_pm_install ripgrep >/dev/null 2>&1
    check "$pm: a failed install returns non-zero" 1 $status
    pm_log >/dev/null
end
set -gx FAKE_PM_RC 0

# The package name is one argv element, never re-split or globbed.
set -gx PATH (mk_pm_dir apt)
pm_log >/dev/null
_fish_deps_pm_install 'two words*' >/dev/null 2>&1
check "the package name reaches the manager as one argument" "sudo apt install -y two words* | apt install -y two words*" (pm_log)

# =============================================================================
# 3. _fish_deps_pm_upgrade
# =============================================================================
section _fish_deps_pm_upgrade

set -gx PATH $work/pm/empty
set err (_fish_deps_pm_upgrade ripgrep 2>&1)
check "no package manager returns 1" 1 $status
check "no package manager is reported" true (string match -q '*No supported package manager*' -- "$err"; and echo true; or echo false)

set cases \
    "paru|paru -S --noconfirm ripgrep" \
    "yay|yay -S --noconfirm ripgrep" \
    "pacman|sudo pacman -S --noconfirm ripgrep | pacman -S --noconfirm ripgrep" \
    "apt|sudo apt install --only-upgrade -y ripgrep | apt install --only-upgrade -y ripgrep" \
    "brew|brew upgrade ripgrep" \
    "pkg|sudo pkg upgrade -y ripgrep | pkg upgrade -y ripgrep" \
    "dnf|sudo dnf upgrade -y ripgrep | dnf upgrade -y ripgrep" \
    "zypper|sudo zypper --non-interactive update ripgrep | zypper --non-interactive update ripgrep" \
    "yum|sudo yum update -y ripgrep | yum update -y ripgrep"
for c in $cases
    set -l pm (string split -m1 '|' -- $c)[1]
    set -l want (string split -m1 '|' -- $c)[2]
    set -gx PATH (mk_pm_dir $pm)
    pm_log >/dev/null

    set -gx FAKE_PM_RC 0
    _fish_deps_pm_upgrade ripgrep >/dev/null 2>&1
    check "$pm: success returns 0" 0 $status
    check "$pm: runs the expected command" $want (pm_log)

    set -gx FAKE_PM_RC 100
    _fish_deps_pm_upgrade ripgrep >/dev/null 2>&1
    check "$pm: a failed upgrade returns non-zero" 100 $status
    pm_log >/dev/null
end
set -gx FAKE_PM_RC 0

# An unrecognized manager must fail loudly, never read as an upgrade (#311).
function _fish_deps_detect_pm
    echo nosuch
end
set err (_fish_deps_pm_upgrade ripgrep 2>&1)
check "an unsupported manager returns 1" 1 $status
check "an unsupported manager is reported" true (string match -q "*unsupported package manager 'nosuch'*" -- "$err"; and echo true; or echo false)
functions -e _fish_deps_detect_pm

set -gx PATH $_real_path

# =============================================================================
# 4. _fish_deps_status
# =============================================================================
section _fish_deps_status

# PATH holds only stubs: zoxide present (found), plus an old fish that must
# be flagged; fzf (required) is missing. Everything else is missing. NO_COLOR gives text labels.
set -l st $work/status-bin
mkdir -p $st
printf '#!/bin/sh\nexit 0\n' >$st/zoxide
printf '#!/bin/sh\necho "fish, version 3.7.1"\n' >$st/fish
chmod +x $st/zoxide $st/fish
# __fish_real_command needs grep to read past wrapper scripts; not a catalog tool.
ln -s (command -s grep) $st/grep
printf 'ID=debian\n' >$work/os-release-debian
printf 'ID=cachyos\nID_LIKE=arch\n' >$work/os-release-arch

set -gx NO_COLOR 1
set -gx __fish_deps_os_release $work/os-release-debian
set -gx PATH $st
set -l out (_fish_deps_status 2>&1)
set -l rc $status
set -gx PATH $_real_path

check "status returns 0" 0 $rc
for h in "Required Dependencies" "Recommended Dependencies" "Optional Dependencies" "Terminal Emulators" Integrations
    check "prints the '$h' heading" true (contains -- $h $out; and echo true; or echo false)
end
check "a present tool is reported with its path" true (string match -q "*zoxide (Found at $st/zoxide)*" -- $out; and echo true; or echo false)
check "fish < 4 is flagged for upgrade" true (string match -q '*fish (version 3.7.1 — upgrade to 4.0+ required)*' -- $out; and echo true; or echo false)
check "a missing required tool is an error" true (string match -q '*[error] fzf (Not installed)*' -- $out; and echo true; or echo false)
check "a missing recommended tool is a warning" true (string match -q '*[warn] starship (Not installed)*' -- $out; and echo true; or echo false)
check "a missing optional tool is neither" true (string match -qr '^ – btop \(Not installed\)$' -- $out; and echo true; or echo false)
check "paru off Arch is not applicable, not missing" true (string match -q '*paru (Arch only*' -- $out; and echo true; or echo false)
check "the helper function is cleaned up" false (functions -q __fds_print_dep; and echo true; or echo false)

# Every catalog entry appears exactly once.
set -l missing_rows
for b in $_fdc_bins
    set -l hits (string match -e -- " $b " $out)
    test (count $hits) -eq 1; or set -a missing_rows $b
end
check "every catalog binary has exactly one row" "" "$missing_rows"

set -gx __fish_deps_os_release $work/os-release-arch
set -gx PATH $st
set out (_fish_deps_status 2>&1)
set -gx PATH $_real_path
check "paru on Arch is a missing recommended tool" true (string match -q '*[warn] paru (Not installed)*' -- $out; and echo true; or echo false)
set -e __fish_deps_os_release
set -e NO_COLOR

# =============================================================================
# 5. _fish_deps_win32yank_binary
# =============================================================================
section _fish_deps_win32yank_binary

# The download+verify step is _fish_deps_fetch_verified (covered in
# test-fish-deps.fish); here it and unzip are stubs, so the install plumbing
# and its status are what is under test. The stub records the URL, digest
# and temp dir it was handed.
set -g _fv_rc 0
set -g _fv_args
function _fish_deps_fetch_verified
    set -g _fv_args $argv
    test $_fv_rc -eq 0; or return 1
    printf zip >$argv[2]
end
set -g _unzip_rc 0
function unzip
    set -l d $argv[-1]
    test $_unzip_rc -eq 0; or return 9
    printf '#!/bin/sh\n' >$d/win32yank.exe
end

set -l dest $HOME/.local/bin/win32yank.exe
_fish_deps_win32yank_binary
check "install succeeds" 0 $status
check "binary lands in ~/.local/bin" true (test -f $dest; and echo true; or echo false)
check "binary is executable" true (test -x $dest; and echo true; or echo false)
check "download is the pinned release" https://github.com/equalsraf/win32yank/releases/download/v0.1.1/win32yank-x64.zip $_fv_args[1]
check "download is verified against the pinned digest" 247c9a05b94387a884b49d3db13f806b1677dfc38020f955f719be6902260cd6 $_fv_args[3]
check "the temp dir is removed" false (test -e (dirname $_fv_args[2]); and echo true; or echo false)

command rm -f $dest
set -g _fv_rc 1
_fish_deps_win32yank_binary
check "a failed/unverified download returns 1" 1 $status
check "a failed download installs nothing" false (test -e $dest; and echo true; or echo false)
check "the temp dir is removed on failure" false (test -e (dirname $_fv_args[2]); and echo true; or echo false)

set -g _fv_rc 0
set -g _unzip_rc 1
_fish_deps_win32yank_binary
check "a failed unzip returns 1" 1 $status
check "a failed unzip installs nothing" false (test -e $dest; and echo true; or echo false)
functions -e _fish_deps_fetch_verified unzip

command rm -rf $work
report
