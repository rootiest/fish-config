#!/usr/bin/env fish
# Copyright (C) 2026 Rootiest
# SPDX-License-Identifier: AGPL-3.0-or-later
#
# MODE: isolated

source (realpath (dirname (status filename)))/lib.fish
set -p fish_function_path $repo_root/functions
set -gx TERM xterm-256color
set -g __fish_config_dir $repo_root 2>/dev/null; or true

# =============================================================================
# 1. sponge_filter_secrets: Credential Leakage Prevention
# =============================================================================
section sponge_filter_secrets

# Export test variables matching sensitive heuristics
set -gx MY_AWS_SECRET_ACCESS_KEY wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY
set -gx GITHUB_TOKEN ghp_0123456789abcdefghijklmnopqrstuv
set -gx KOPIA_PASSWORD MyLongPassword123

# Secret appears in command -> returns 0 (filtered from history)
sponge_filter_secrets "aws s3 cp file.txt s3://bucket/ --key wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY"
check "aws secret in command filtered" 0 $status

sponge_filter_secrets "curl -H 'Authorization: token ghp_0123456789abcdefghijklmnopqrstuv' https://api.github.com"
check "github token in command filtered" 0 $status

sponge_filter_secrets "kopia repository connect --password MyLongPassword123"
check "kopia password in command filtered" 0 $status

# Clean command with no secret -> returns 1 (kept in history)
sponge_filter_secrets "git status -s"
check "clean command retained" 1 $status

sponge_filter_secrets "echo 'Hello World'"
check "ordinary echo retained" 1 $status

# Short secret (<= 8 chars) -> ignored, returns 1 (kept)
set -gx SHORT_API_KEY 12345678
set -gx SHORT_SECRET short
sponge_filter_secrets "curl -H 'X-Key: 12345678' https://example.com"
check "8-char secret ignored" 1 $status

sponge_filter_secrets "echo short"
check "short secret ignored" 1 $status

# Path-like secret (starts with / or ~) -> ignored, returns 1 (kept)
set -gx SECRET_FILE_PATH "/home/rootiest/.token"
set -gx HOME_SECRET_PATH "~/secrets/token.txt"
sponge_filter_secrets "cat /home/rootiest/.token"
check "path-like secret starting with / ignored" 1 $status

sponge_filter_secrets "source ~/secrets/token.txt"
check "path-like secret starting with ~ ignored" 1 $status

# Empty or unset variable -> handled without error, returns 1
set -gx DUMMY_API_KEY ""
sponge_filter_secrets "echo normal command"
check "empty sensitive var does not cause crash or false filter" 1 $status

# Clean up exported test variables
set -e MY_AWS_SECRET_ACCESS_KEY
set -e GITHUB_TOKEN
set -e KOPIA_PASSWORD
set -e SHORT_API_KEY
set -e SHORT_SECRET
set -e SECRET_FILE_PATH
set -e HOME_SECRET_PATH
set -e DUMMY_API_KEY

# =============================================================================
# 2. _fish_mkdir_p: Directory Creation with Feedback
# =============================================================================
section _fish_mkdir_p

set -l mkdir_sandbox (mktemp -d)

# Empty argument returns status 1
_fish_mkdir_p
check "empty argument returns 1" 1 $status

# Existing directory returns status 0
_fish_mkdir_p $mkdir_sandbox
check "existing directory returns 0" 0 $status

# --path: creates directory and prints single line
set -l out_path (_fish_mkdir_p --path $mkdir_sandbox/dirA/dirB)
check "--path returns 0" 0 $status
check "--path creates directory" true (test -d $mkdir_sandbox/dirA/dirB; and echo true; or echo false)
check "--path outputs 'Created directory:'" true (string match -q "*Created directory:*" -- "$out_path"; and echo true; or echo false)

# --silent: creates directory and suppresses stdout
set -l out_silent (_fish_mkdir_p --silent $mkdir_sandbox/dirC/dirD)
check "--silent returns 0" 0 $status
check "--silent creates directory" true (test -d $mkdir_sandbox/dirC/dirD; and echo true; or echo false)
check "--silent produces empty stdout" "" "$out_silent"

# -s short flag
set -l out_silent_short (_fish_mkdir_p -s $mkdir_sandbox/dirC/dirD/sub)
check "-s returns 0" 0 $status
check "-s creates directory" true (test -d $mkdir_sandbox/dirC/dirD/sub; and echo true; or echo false)
check "-s produces empty stdout" "" "$out_silent_short"

# --tree: creates directory and displays tree view with branch glyph
set -l out_tree (_fish_mkdir_p --tree $mkdir_sandbox/dirE/dirF)
check "--tree returns 0" 0 $status
check "--tree creates directory" true (test -d $mkdir_sandbox/dirE/dirF; and echo true; or echo false)
check "--tree outputs 'Created directories:'" true (string match -q "*Created directories:*" -- "$out_tree"; and echo true; or echo false)
check "--tree outputs branch glyph └──" true (string match -q "*└──*" -- "$out_tree"; and echo true; or echo false)

# Default mode without mode flag uses path mode
set -l out_default (_fish_mkdir_p $mkdir_sandbox/dirG/dirH)
check "default mode returns 0" 0 $status
check "default mode creates directory" true (test -d $mkdir_sandbox/dirG/dirH; and echo true; or echo false)
check "default mode outputs 'Created directory:'" true (string match -q "*Created directory:*" -- "$out_default"; and echo true; or echo false)

# Cleanup
rm -rf $mkdir_sandbox

# =============================================================================
# 3. _scrollback_prune_junk: History Log Pruning
# =============================================================================
section _scrollback_prune_junk

set -l prune_sandbox (mktemp -d)

# Create test files in prune sandbox
# Empty files (must be deleted)
touch $prune_sandbox/empty.log
touch $prune_sandbox/empty.txt

# 1-line noise files (must be deleted)
echo "lone command prompt" >$prune_sandbox/single_line.log
echo "[exited]" >$prune_sandbox/single_line.txt
printf "\n\n  \n  single line with surrounding whitespace \n\n" >$prune_sandbox/whitespace_single.log

# Kitty tab-rename UI noise captures (must be deleted)
printf "%s\n" "Prompt start" "Enter the new title for this tab below" Done >$prune_sandbox/scrollback_kitty.log
printf "%s\n" Header "Enter the new title for this tab below" Tail >$prune_sandbox/scrollback_rename.txt

# Valid multi-line log files (>1 meaningful lines) (MUST BE PRESERVED)
printf "%s\n" "Session started at 12:00" "Command: ls -la" "Output: total 0" >$prune_sandbox/valid_session.log
printf "%s\n" "Build step 1 passed" "Build step 2 passed" >$prune_sandbox/valid_session.txt
printf "%s\n" "scrollback line 1" "scrollback line 2" "scrollback line 3" >$prune_sandbox/scrollback_valid.log

# Run prune
_scrollback_prune_junk $prune_sandbox

# Assertions: empty files deleted
check "empty .log deleted" false (test -f $prune_sandbox/empty.log; and echo true; or echo false)
check "empty .txt deleted" false (test -f $prune_sandbox/empty.txt; and echo true; or echo false)

# Assertions: 1-line noise files deleted
check "single-line .log deleted" false (test -f $prune_sandbox/single_line.log; and echo true; or echo false)
check "single-line .txt deleted" false (test -f $prune_sandbox/single_line.txt; and echo true; or echo false)
check "whitespace single-line .log deleted" false (test -f $prune_sandbox/whitespace_single.log; and echo true; or echo false)

# Assertions: kitty tab rename prompt files deleted
check "kitty tab rename scrollback_*.log deleted" false (test -f $prune_sandbox/scrollback_kitty.log; and echo true; or echo false)
check "kitty tab rename scrollback_*.txt deleted" false (test -f $prune_sandbox/scrollback_rename.txt; and echo true; or echo false)

# Assertions: valid multi-line files preserved
check "valid multi-line .log preserved" true (test -f $prune_sandbox/valid_session.log; and echo true; or echo false)
check "valid multi-line .txt preserved" true (test -f $prune_sandbox/valid_session.txt; and echo true; or echo false)
check "valid multi-line scrollback_valid.log preserved" true (test -f $prune_sandbox/scrollback_valid.log; and echo true; or echo false)

# Assertions: non-existent directory handled safely
_scrollback_prune_junk $prune_sandbox/nonexistent
check "nonexistent directory returns 0" 0 $status

# Cleanup
rm -rf $prune_sandbox

# =============================================================================
# 4. sudo-toggle: Sudo NOPASSWD Security Toggle
# =============================================================================
section sudo-toggle

set -l sudo_sandbox (mktemp -d)
set -g _mock_sudoers_file "$sudo_sandbox/nofail-toggle"

# Mock sudo function to intercept stat, truncate, and tee for /etc/sudoers.d/nofail-toggle
function sudo
    set -l cmd_args $argv
    while test (count $cmd_args) -gt 0; and string match -qr '^-[a-zA-Z]' -- $cmd_args[1]
        set -e cmd_args[1]
    end

    switch $cmd_args[1]
        case stat
            if test -f "$_mock_sudoers_file"
                command stat -c %s "$_mock_sudoers_file"
            else
                return 1
            end
        case truncate
            if test -f "$_mock_sudoers_file"
                command truncate -s 0 "$_mock_sudoers_file"
            end
        case tee
            command tee "$_mock_sudoers_file"
        case '*'
            return 1
    end
end

# Case 1: When file is missing -> writes rule, outputs DISABLED (Bypass active)
rm -f "$_mock_sudoers_file"
set -l out_missing (sudo-toggle)
check "missing file: returns 0" 0 $status
check "missing file: displays DISABLED" true (string match -q "*🔓 Sudo security: DISABLED*" -- "$out_missing"; and echo true; or echo false)
check "missing file: creates sudoers file" true (test -f "$_mock_sudoers_file"; and echo true; or echo false)
check "missing file: writes content to file" true (test -s "$_mock_sudoers_file"; and echo true; or echo false)

# Case 2: When file has size > 0 (bypass active) -> truncates to 0, outputs ENABLED
set -l out_active (sudo-toggle)
check "active bypass: returns 0" 0 $status
check "active bypass: displays ENABLED" true (string match -q "*🔒 Sudo security: ENABLED*" -- "$out_active"; and echo true; or echo false)
check "active bypass: truncates file to 0 bytes" false (test -s "$_mock_sudoers_file"; and echo true; or echo false)

# Case 3: When file exists but has size 0 -> writes rule, outputs DISABLED
set -l out_empty (sudo-toggle)
check "empty file: returns 0" 0 $status
check "empty file: displays DISABLED" true (string match -q "*🔓 Sudo security: DISABLED*" -- "$out_empty"; and echo true; or echo false)
check "empty file: writes content to file" true (test -s "$_mock_sudoers_file"; and echo true; or echo false)

# Case 4: --help flag displays header documentation
set -l out_help (sudo-toggle --help)
check "sudo-toggle --help returns 0" 0 $status
check "sudo-toggle --help contains USAGE" true (string match -q "*USAGE*" -- "$out_help"; and echo true; or echo false)

# Cleanup
functions -e sudo
set -e _mock_sudoers_file
rm -rf $sudo_sandbox

# =============================================================================
# 5. spark: Sparkline Bar Chart Generation
# =============================================================================
section spark

# Number array 1 2 3 4 5 produces sparkline characters
set -l out_seq (spark 1 2 3 4 5)
check "spark 1 2 3 4 5 generates sparkline" "▁▃▄▆█" "$out_seq"

# Numbers via stdin
set -l out_stdin (printf "%s\n" 1 2 3 4 5 | spark)
check "spark via stdin generates sparkline" "▁▃▄▆█" "$out_stdin"

# Clamping with --min and --max
set -l out_clamped (spark --min=0 --max=10 0 5 10)
check "spark clamped with --min and --max" "▁▄█" "$out_clamped"

# Version flag
set -l out_ver (spark --version)
check "spark --version contains version 1.1.0" true (string match -q "*spark, version 1.1.0*" -- "$out_ver"; and echo true; or echo false)

set -l out_ver_s (spark -v)
check "spark -v contains version 1.1.0" true (string match -q "*spark, version 1.1.0*" -- "$out_ver_s"; and echo true; or echo false)

# Help flag
set -l out_spark_help (spark --help)
check "spark --help contains Usage:" true (string match -q "*Usage:*" -- "$out_spark_help"; and echo true; or echo false)

set -l out_spark_help_s (spark -h)
check "spark -h contains Usage:" true (string match -q "*Usage:*" -- "$out_spark_help_s"; and echo true; or echo false)

# =============================================================================
# 6. pkg: System Package Manager Abstraction
# =============================================================================
section pkg

# Test missing package manager detection
function _fish_deps_detect_pm
    return 1
end

set -l err_no_pm (pkg somepkg 2>&1 >/dev/null)
check "missing package manager returns 1" 1 $status
check "missing package manager reports error on stderr" true (string match -q "*error: no supported package manager found*" -- "$err_no_pm"; and echo true; or echo false)

# Test pacman integration with mock detection and mock commands
function _fish_deps_detect_pm
    echo pacman
end

set -g _pacman_log
function pacman
    set -ga _pacman_log (string join -- " " $argv)
    if test "$argv[1]" = -Qi
        if test "$argv[2]" = installed-pkg
            return 0
        else
            return 1
        end
    end
    return 0
end

function sudo
    $argv
end

# Auto mode with installed package -> invokes pacman -Qi and then removes (-Rns)
set -g _pacman_log
set -l out_installed (pkg installed-pkg)
check "pkg installed-pkg returns 0" 0 $status
check "pkg installed-pkg outputs Removing" true (string match -q "*Removing*installed-pkg*" -- "$out_installed"; and echo true; or echo false)
check "pkg installed-pkg runs pacman -Qi query" true (string match -q "*-Qi installed-pkg*" -- "$_pacman_log"; and echo true; or echo false)
check "pkg installed-pkg runs pacman -Rns removal" true (string match -q "*-Rns installed-pkg*" -- "$_pacman_log"; and echo true; or echo false)

# Auto mode with uninstalled package -> invokes pacman -Qi and then installs (-S)
set -g _pacman_log
set -l out_uninstalled (pkg uninstalled-pkg)
check "pkg uninstalled-pkg returns 0" 0 $status
check "pkg uninstalled-pkg outputs Installing" true (string match -q "*Installing*uninstalled-pkg*" -- "$out_uninstalled"; and echo true; or echo false)
check "pkg uninstalled-pkg runs pacman -Qi query" true (string match -q "*-Qi uninstalled-pkg*" -- "$_pacman_log"; and echo true; or echo false)
check "pkg uninstalled-pkg runs pacman -S installation" true (string match -q "*-S uninstalled-pkg*" -- "$_pacman_log"; and echo true; or echo false)

# Explicit install mode (-i) -> directly installs
set -g _pacman_log
set -l out_force_install (pkg -i new-pkg)
check "pkg -i returns 0" 0 $status
check "pkg -i outputs Installing" true (string match -q "*Installing*new-pkg*" -- "$out_force_install"; and echo true; or echo false)
check "pkg -i runs pacman -S" true (string match -q "*-S new-pkg*" -- "$_pacman_log"; and echo true; or echo false)

# Explicit uninstall mode (-u) -> directly removes
set -g _pacman_log
set -l out_force_uninstall (pkg -u old-pkg)
check "pkg -u returns 0" 0 $status
check "pkg -u outputs Removing" true (string match -q "*Removing*old-pkg*" -- "$out_force_uninstall"; and echo true; or echo false)
check "pkg -u runs pacman -Rns" true (string match -q "*-Rns old-pkg*" -- "$_pacman_log"; and echo true; or echo false)

# Help flag
set -l out_pkg_help (pkg --help)
check "pkg --help returns 0" 0 $status
check "pkg --help outputs Usage" true (string match -q "*Usage:*pkg*" -- "$out_pkg_help"; and echo true; or echo false)

# No arguments -> prints usage and returns 0
set -l out_pkg_empty (pkg)
check "pkg with no arguments returns 0" 0 $status
check "pkg with no arguments outputs Usage" true (string match -q "*Usage:*pkg*" -- "$out_pkg_empty"; and echo true; or echo false)

# Unknown flag -> returns 1 and prints error to stderr
set -l err_pkg_flag (pkg --unrecognized-option 2>&1 >/dev/null)
check "pkg unknown flag returns 1" 1 $status
check "pkg unknown flag outputs error on stderr" true (string match -q "*error:*unknown flag*--unrecognized-option*" -- "$err_pkg_flag"; and echo true; or echo false)

# Cleanup
functions -e _fish_deps_detect_pm pacman sudo
set -e _pacman_log

# =============================================================================
# Report
# =============================================================================
report
