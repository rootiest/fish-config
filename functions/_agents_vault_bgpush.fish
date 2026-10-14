# Copyright (C) 2026 Rootiest
# SPDX-License-Identifier: AGPL-3.0-or-later

# COMPONENT
#   autoexec/sync
#
# DEPENDENCIES
#   _agents_vault_dir, __fish_variable_check, __fish_config_op_enabled, git,
#   timeout
#
# SYNOPSIS
#   _agents_vault_bgpush due <vault>
#   _agents_vault_bgpush spawn <vault>
#   _agents_vault_bgpush run <vault>
#   _agents_vault_bgpush state <vault>
#
# DESCRIPTION
#   Backs the non-blocking push that `agents-vault --push-bg` starts on an
#   agent launch. It is the same pattern as conf.d/auto-pull.fish: the
#   foreground does a few cheap local checks, hands a bounded job to a
#   --no-config child, and returns at once. It is not meant to be called
#   directly.
#
#   Why this is safe to run in front of every launch:
#     - The foreground does no network I/O. The due check reads local refs
#       only, so a launch with nothing new to send costs no process.
#     - The worker never prompts: GIT_TERMINAL_PROMPT=0, GIT_ASKPASS and
#       SSH_ASKPASS are neutralized, and ssh gets BatchMode and a connect
#       timeout appended to the user's own ssh command.
#     - Its runtime is bounded: the push runs under timeout(1), 60 seconds,
#       because git has no connect timeout of its own for https. Without
#       timeout(1) nothing is started at all.
#     - Pushes do not stack: an atomic mkdir lock inside .git admits one
#       worker, and a lock older than two minutes (a killed worker) is
#       reclaimed. A failed attempt also backs off for ten minutes, so an
#       offline laptop does not start a process on every launch.
#     - It only pushes. It never pulls, rebases, stashes, or touches the
#       index or the work tree, so it cannot collide with the foreground
#       commit the next launch makes. A remote that has moved on rejects
#       the push, which is recorded as a failure; `agents-vault --push`
#       is the reconciling path.
#     - Every outcome is written to .git/agent-vault-bgpush.state (inside
#       .git, so never committed), which is how a silent background
#       failure gets surfaced in `agents-vault --status`.
#
# ARGUMENTS
#   due     Exit 0 when a worker should be started now. Otherwise exit 1
#           and print the reason on stdout
#   spawn   Start the worker detached in the background
#   run     The worker itself: lock, push under timeout, record, unlock
#   state   Print "<class><TAB><text>" describing the mechanism and the last
#           outcome, class being ok, warn, err or dim
#   vault   Absolute path of the vault
#
# EXIT STATUS
#   0  due: a push is due. spawn: started. run: finished (whatever the push
#      did; see the state file). state: always
#   1  due: not due (reason printed). spawn: could not start. run: could
#      not run at all
#
# EXAMPLE
#   _agents_vault_bgpush due ~/.local/share/agent-vault
function _agents_vault_bgpush --argument-names action vault --description 'bounded background push of the agent vault'
    set -l bound 60
    # Test-only: lets the suite exercise the bound in seconds, not a minute.
    string match -qr '^[1-9]\d{0,2}$' -- "$__fish_agent_vault_bgpush_timeout"
    and set bound $__fish_agent_vault_bgpush_timeout
    set -l lock_stale 120
    set -l backoff 600

    test -n "$vault"; or return 1
    set -l gd "$vault/.git"
    set -l lock "$gd/agent-vault-bgpush.lock"
    set -l statef "$gd/agent-vault-bgpush.state"

    #   ───────────────────────────── worker ─────────────────────────────
    # Self-contained on purpose: it runs in `fish --no-config` after
    # sourcing only this file, so it may use builtins and external commands
    # and nothing else from this repository.
    if test "$action" = run
        test -d "$gd"; or return 1
        if test -d "$lock"
            set -l born (command stat -c %Y -- "$lock" 2>/dev/null)
            test -n "$born"; or set born 0
            if test (math (date +%s) - $born) -gt $lock_stale
                command rm -rf -- "$lock"
            end
        end
        # mkdir is the atomic test-and-set. Losing it is not an error: a
        # worker is already doing this exact job.
        command mkdir -- "$lock" 2>/dev/null; or return 0
        echo $fish_pid >"$lock/pid"

        set -l result ok
        set -l msg pushed
        if not command git -C "$vault" remote get-url origin >/dev/null 2>&1
            set result fail
            set msg "no remote configured"
        else
            set -l ssh_cmd $GIT_SSH_COMMAND
            test -n "$ssh_cmd"; or set ssh_cmd (command git -C "$vault" config core.sshCommand 2>/dev/null)
            test -n "$ssh_cmd"; or set ssh_cmd ssh
            set -l errf (command mktemp 2>/dev/null)
            command timeout $bound env GIT_TERMINAL_PROMPT=0 GIT_ASKPASS=true SSH_ASKPASS=true \
                GIT_SSH_COMMAND="$ssh_cmd -o BatchMode=yes -o ConnectTimeout=10" \
                git -C "$vault" push -q origin HEAD </dev/null >/dev/null 2>"$errf"
            set -l rc $status
            if test $rc -ne 0
                set result fail
                if test $rc -eq 124
                    set msg "timed out after "$bound"s"
                else
                    set msg (string trim -- (head -n 1 "$errf" 2>/dev/null) | string sub -l 160)
                    test -n "$msg"; or set msg "push failed (exit $rc)"
                end
            end
            test -n "$errf"; and command rm -f -- "$errf"
        end
        printf '%s %s %s\n' (date +%s) $result "$msg" >"$statef"
        command rm -rf -- "$lock"
        return 0
    end

    #   ─────────────────────── hard prerequisites ───────────────────────
    # Shared by due and state: reasons the mechanism is switched off
    # regardless of what the vault holds.
    set -l off
    __fish_variable_check __fish_agent_vault_bgpush
    set -l optout $status
    if not __fish_config_op_enabled (status current-function)
        set off "auto-execution (C2) is disabled"
    else if test $optout -eq 1
        set off "turned off by __fish_agent_vault_bgpush"
    end
    if test -z "$off"; and not type -q timeout
        set off "timeout(1) is unavailable, so the push cannot be bounded"
    end

    set -l now (date +%s)
    set -l last_t 0
    set -l last_r
    set -l last_m
    if test -r "$statef"
        set -l parts (string split -m 2 ' ' -- (head -n 1 "$statef"))
        set last_t $parts[1]
        set last_r $parts[2]
        set last_m $parts[3]
        string match -qr '^\d+$' -- "$last_t"; or set last_t 0
    end

    if test "$action" = state
        if test -n "$off"
            printf 'dim\tbackground push on launch is off: %s\n' "$off"
            return 0
        end
        set -l ago "never run"
        if test $last_t -gt 0
            set -l d (math $now - $last_t)
            if test $d -lt 90
                set ago "$d""s ago"
            else if test $d -lt 5400
                set ago (math -s0 $d / 60)"m ago"
            else if test $d -lt 172800
                set ago (math -s0 $d / 3600)"h ago"
            else
                set ago (math -s0 $d / 86400)"d ago"
            end
        end
        if not command git -C "$vault" remote get-url origin >/dev/null 2>&1
            printf 'dim\tbackground push on launch is on, idle: no remote configured\n'
        else if test "$last_r" = ok
            printf 'ok\tbackground push on launch: last push succeeded %s\n' "$ago"
        else if test "$last_r" = fail
            printf 'err\tbackground push on launch: last attempt FAILED %s (%s); run agents-vault --push to see and fix\n' "$ago" "$last_m"
        else
            printf 'dim\tbackground push on launch is on; no push has run yet\n'
        end
        return 0
    end

    #   ───────────────────────── due / spawn ────────────────────────────
    if test "$action" = due
        if test -n "$off"
            echo "$off"
            return 1
        end
        if not test -d "$gd"
            echo "no vault repository"
            return 1
        end
        if not command git -C "$vault" remote get-url origin >/dev/null 2>&1
            echo "no remote"
            return 1
        end
        set -l head (command git -C "$vault" rev-parse -q --verify HEAD 2>/dev/null)
        if test -z "$head"
            echo "nothing committed yet"
            return 1
        end
        # Anything to send? Local refs only. With an upstream, count what
        # is ahead of it; without one (agents-vault pushes with a plain
        # `push origin HEAD`, which sets none) compare against the
        # remote-tracking ref that push leaves behind.
        set -l fresh 0
        if command git -C "$vault" rev-parse --abbrev-ref --symbolic-full-name '@{u}' >/dev/null 2>&1
            set -l ahead (command git -C "$vault" rev-list --count '@{u}..HEAD' 2>/dev/null)
            test -n "$ahead"; and test "$ahead" != 0; and set fresh 1
        else
            set -l br (command git -C "$vault" rev-parse --abbrev-ref HEAD 2>/dev/null)
            set -l tr (command git -C "$vault" rev-parse -q --verify "refs/remotes/origin/$br" 2>/dev/null)
            test "$tr" != "$head"; and set fresh 1
        end
        if test $fresh -eq 0
            echo "nothing new to push"
            return 1
        end
        if test -d "$lock"
            set -l born (command stat -c %Y -- "$lock" 2>/dev/null)
            test -n "$born"; or set born 0
            if test (math $now - $born) -le $lock_stale
                echo "a background push is already running"
                return 1
            end
        end
        if test "$last_r" = fail; and test (math $now - $last_t) -lt $backoff
            echo "backing off after a recent failure"
            return 1
        end
        return 0
    end

    if test "$action" = spawn
        set -l worker (functions --details _agents_vault_bgpush 2>/dev/null)
        test -r "$worker"; or set worker "$__fish_config_dir/functions/_agents_vault_bgpush.fish"
        test -r "$worker"; or return 1
        # A --no-config child sources just the worker, so it stays fast
        # and free of shell side-effects. Detached and fully redirected:
        # it must not hold the launching terminal's output or input.
        fish --no-config -c 'source $argv[1]; _agents_vault_bgpush run $argv[2]' -- "$worker" "$vault" </dev/null >/dev/null 2>&1 &
        disown 2>/dev/null
        return 0
    end

    echo "_agents_vault_bgpush: unknown action '$action'" >&2
    return 2
end
