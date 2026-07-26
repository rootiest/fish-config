# Copyright (C) 2026 Rootiest
# SPDX-License-Identifier: AGPL-3.0-or-later

# CATEGORY
#   14-miscellaneous
#
# SYNOPSIS
#   config-update [-h | --help] [-f | --force] [-n | --dry-run]
#
# DESCRIPTION
#   Pulls the latest fish shell configuration from the upstream repository
#   (https://git.rootiest.dev/rootiest/fish-config.git) into ~/.config/fish.
#   The remote URL is hard-coded so the update works even if the local clone
#   has no configured remote. Git output is suppressed; status is reported
#   through colored messages. After a successful pull the function prints a
#   short summary of changed files; run `exec fish` to reload the shell.
#
# ARGUMENTS
#   -h, --help      Show this help message and exit
#   -f, --force     Stash local changes before pulling, then pop the stash
#   -n, --dry-run   Check for upstream changes without applying them
#
# RETURNS
#   0  Config updated (or already up to date)
#   1  Update failed (network error, merge conflict, or not a git repo)
#
# EXAMPLE
#   config-update
#   config-update --dry-run
#   config-update --force
function config-update --description 'Pull latest fish config from upstream'
    set -l c_head  (set_color --bold cyan)
    set -l c_cmd   (set_color --bold white)
    set -l c_flag  (set_color yellow)
    set -l c_ok    (set_color green)
    set -l c_warn  (set_color yellow)
    set -l c_err   (set_color red)
    set -l c_dim   (set_color brblack)
    set -l c_reset (set_color normal)

    set -l REMOTE_URL https://git.rootiest.dev/rootiest/fish-config.git
    set -l CONFIG_DIR ~/.config/fish
    set -l opt_force 0
    set -l opt_dry 0

    # ── parse flags ───────────────────────────────────────────────
    for arg in $argv
        switch $arg
            case -h --help
                echo "$c_head""Usage:$c_reset $c_cmd""config-update$c_reset $c_flag""[-h] [-f] [-n]$c_reset"
                echo
                echo "  Pull the latest fish config from upstream and apply it locally."
                echo
                echo "$c_head""Options:$c_reset"
                echo "  $c_flag-h$c_reset, $c_flag--help$c_reset       Show this help message"
                echo "  $c_flag-f$c_reset, $c_flag--force$c_reset      Stash local changes, pull, then restore stash"
                echo "  $c_flag-n$c_reset, $c_flag--dry-run$c_reset    Check for updates without applying them"
                echo
                echo "$c_head""Remote:$c_reset $c_dim""$REMOTE_URL$c_reset"
                return 0
            case -f --force
                set opt_force 1
            case -n --dry-run
                set opt_dry 1
            case '*'
                echo "$c_err""Unknown option: $arg$c_reset" >&2
                echo "Run $c_cmd""config-update --help$c_reset for usage." >&2
                return 1
        end
    end

    # ── verify config dir is a git repo ──────────────────────────
    if not test -d "$CONFIG_DIR/.git"
        echo "$c_err""Error:$c_reset $c_dim""$CONFIG_DIR$c_reset is not a git repository." >&2
        return 1
    end

    echo "$c_head""Fish Config Updater$c_reset"
    echo "$c_dim""Remote: $REMOTE_URL$c_reset"
    echo

    # ── fetch upstream ────────────────────────────────────────────
    echo "$c_dim""→ Fetching upstream changes...$c_reset"
    if not git -C "$CONFIG_DIR" fetch "$REMOTE_URL" main:refs/remotes/_config_update/main 2>/dev/null
        echo "$c_err""Error:$c_reset Could not reach upstream remote." >&2
        echo "$c_dim""Check your internet connection and try again.$c_reset" >&2
        git -C "$CONFIG_DIR" branch -D -r _config_update/main 2>/dev/null 1>/dev/null
        return 1
    end

    # ── compare local HEAD to upstream ───────────────────────────
    set -l local_sha  (git -C "$CONFIG_DIR" rev-parse HEAD 2>/dev/null)
    set -l remote_sha (git -C "$CONFIG_DIR" rev-parse _config_update/main 2>/dev/null)

    if test "$local_sha" = "$remote_sha"
        echo "$c_ok""✓ Already up to date.$c_reset"
        git -C "$CONFIG_DIR" branch -D -r _config_update/main 2>/dev/null 1>/dev/null
        return 0
    end

    # ── count incoming commits ────────────────────────────────────
    set -l ahead (git -C "$CONFIG_DIR" rev-list HEAD.._config_update/main 2>/dev/null | count)
    echo "$c_ok""$ahead new commit(s) available upstream.$c_reset"

    # ── list changed files (preview) ─────────────────────────────
    set -l changed_files (git -C "$CONFIG_DIR" diff --name-only HEAD _config_update/main 2>/dev/null)
    if test (count $changed_files) -gt 0
        echo
        echo "$c_head""Changed files:$c_reset"
        for f in $changed_files
            echo "  $c_dim""·$c_reset $f"
        end
    end

    # ── dry-run exits here ────────────────────────────────────────
    if test $opt_dry -eq 1
        echo
        echo "$c_warn""Dry run — no changes applied.$c_reset"
        git -C "$CONFIG_DIR" branch -D -r _config_update/main 2>/dev/null 1>/dev/null
        return 0
    end

    echo

    # ── check for local modifications ─────────────────────────────
    set -l dirty (git -C "$CONFIG_DIR" status --porcelain 2>/dev/null)
    if test -n "$dirty"
        if test $opt_force -eq 1
            echo "$c_warn""→ Stashing local changes...$c_reset"
            if not git -C "$CONFIG_DIR" stash push -m "config-update auto-stash" 2>/dev/null 1>/dev/null
                echo "$c_err""Error:$c_reset Could not stash local changes." >&2
                git -C "$CONFIG_DIR" branch -D -r _config_update/main 2>/dev/null 1>/dev/null
                return 1
            end
        else
            echo "$c_warn""Warning:$c_reset You have uncommitted local changes." >&2
            echo "$c_dim""Run with $c_flag--force$c_dim to stash them automatically,$c_reset" >&2
            echo "$c_dim""or commit/stash manually before updating.$c_reset" >&2
            git -C "$CONFIG_DIR" branch -D -r _config_update/main 2>/dev/null 1>/dev/null
            return 1
        end
    end

    # ── apply the update ──────────────────────────────────────────
    echo "$c_dim""→ Applying update...$c_reset"
    if not git -C "$CONFIG_DIR" merge --ff-only _config_update/main 2>/dev/null 1>/dev/null
        # ff-only failed — try a regular merge
        set -l merge_out (git -C "$CONFIG_DIR" merge _config_update/main 2>&1)
        if test $status -ne 0
            echo "$c_err""Error:$c_reset Merge failed — resolve conflicts manually." >&2
            echo "$c_dim""$merge_out$c_reset" >&2
            git -C "$CONFIG_DIR" branch -D -r _config_update/main 2>/dev/null 1>/dev/null
            return 1
        end
    end

    # ── restore stash if we created one ──────────────────────────
    if test $opt_force -eq 1 -a -n "$dirty"
        echo "$c_dim""→ Restoring stashed changes...$c_reset"
        if not git -C "$CONFIG_DIR" stash pop 2>/dev/null 1>/dev/null
            echo "$c_warn""Warning:$c_reset Stash pop had conflicts — resolve manually with $c_cmd""git stash pop$c_reset"
        end
    end

    # ── success summary ───────────────────────────────────────────
    set -l new_sha (git -C "$CONFIG_DIR" rev-parse --short HEAD 2>/dev/null)
    echo "$c_ok""✓ Config updated to $new_sha ($ahead commit(s) applied).$c_reset"
    echo
    echo "$c_dim""Reload your shell or run $c_cmd""exec fish$c_dim to apply changes.$c_reset"

    git -C "$CONFIG_DIR" branch -D -r _config_update/main 2>/dev/null 1>/dev/null
    return 0
end
