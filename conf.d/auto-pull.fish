# Copyright (C) 2026 Rootiest
# SPDX-License-Identifier: AGPL-3.0-or-later

#          ╭──────────────────────────────────────────────────────────╮
#          │                  Auto-Pull (C2 — Autoexec)               │
#          ╰──────────────────────────────────────────────────────────╯
#
# Background, fast-forward-only `git pull` for opted-in repositories. Fires
# when the working directory enters the fish-config repo (always covered as a
# baseline) or any repository registered via the `auto-pull` command. The
# actual sync is delegated to `_auto_pull_sync`, which only ever fast-forwards
# a clean repo — see that function for the full safety contract.
#
# Manage the registry with: auto-pull add / remove / list / status

# C2 guard: when auto-execution is disabled, do not register the handler.
__fish_config_op_enabled (status basename); or exit

# COMPONENT
#   autoexec/sync
#
# SYNOPSIS
#   __auto_pull_on_pwd (event handler, --on-variable PWD)
#
# DESCRIPTION
#   On every directory change, checks whether the new $PWD is inside a
#   registered repository (or the fish-config baseline) and, if so, kicks a
#   background fast-forward. A throttle global ensures it fires once per
#   repository entry rather than on every sub-directory change.
function __auto_pull_on_pwd --on-variable PWD
    set -q __fish_config_dir; or set -g __fish_config_dir $XDG_CONFIG_HOME/fish
    set -q __fish_user_dots_path; or set -l __fish_user_dots_path "$XDG_CONFIG_HOME/.user-dots/fish"
    set -l list "$__fish_user_dots_path/auto-pull.list"

    # Candidate roots: the fish-config repo plus the user's registry.
    set -l roots $__fish_config_dir
    test -r "$list"; and set -a roots (command cat "$list" 2>/dev/null)

    # Find the registered root containing $PWD (exact match or a sub-directory).
    set -l hit
    for r in $roots
        test -n "$r"; or continue
        if test "$PWD" = "$r"; or string match -q -- "$r/*" "$PWD"
            set hit "$r"
            break
        end
    end

    # Outside every registered repo: clear the throttle so re-entry re-syncs.
    if test -z "$hit"
        set -e __auto_pull_last
        return
    end

    # Already synced for this repo entry — skip until we leave and return.
    test "$hit" = "$__auto_pull_last"; and return
    set -g __auto_pull_last "$hit"

    # Background fast-forward. A --no-config child sources just the worker so
    # it stays fast and free of shell side-effects; real `git`, no shadows.
    set -l worker "$__fish_config_dir/functions/_auto_pull_sync.fish"
    test -r "$worker"; or return
    fish --no-config -c 'source $argv[1]; _auto_pull_sync $argv[2]' -- "$worker" "$hit" &
    disown 2>/dev/null
end
