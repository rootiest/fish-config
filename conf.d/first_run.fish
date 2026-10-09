# Copyright (C) 2026 Rootiest
# SPDX-License-Identifier: AGPL-3.0-or-later

#          ╭──────────────────────────────────────────────────────────╮
#          │                First-Run Initialization                  │
#          ╰──────────────────────────────────────────────────────────╯
#
# Runs exactly once on the first interactive fish session after install.
# To reset for testing, run: set -Ue __fish_config_first_run_complete
#
# If the Fisher/plugin bootstrap fails, the universal variable
# __fish_config_bootstrap_pending records the epoch time of the attempt and
# later interactive starts retry only that step, at most once a day.
# To retry now, run: set -U __fish_config_bootstrap_pending 0
#
# COMPONENT
#   site first-run-greeting: greeting/first-run
#   site first-run-bootstrap: autoexec/plugin-management

# Exit early in non-interactive shells (scripts, completions, subshells)
if not status is-interactive
    return
end

# 1 on a retry start: a later session that only re-runs the Fisher bootstrap
# because an earlier attempt failed. 0 on the real first run.
set -l _retry 0

if set -q __fish_config_first_run_complete
    #   ─────────────────────── Retry a failed bootstrap ───────────────────────
    # A failed bootstrap leaves __fish_config_bootstrap_pending set to the epoch
    # time of the last attempt. Without it this is the normal start: one
    # variable test, no forks. With it, retry the bootstrap step only (never the
    # welcome banner or theme), at most once per 24 h and once per shell
    # session. Non-interactive shells never get here (returned above).
    set -q __fish_config_bootstrap_pending; or return
    set -q __fish_config_bootstrap_retry_done; and return
    set -g __fish_config_bootstrap_retry_done 1
    # C2 may have been disabled since the failure: stay silent and idle then.
    __fish_config_op_enabled (status basename) first-run-bootstrap; or return

    # The only fork on this path. A missing/garbage stored value, or one from
    # the future (clock change), counts as "retry now"; an unusable clock
    # means no retry rather than a retry on every start.
    set -l _now (command date +%s 2>/dev/null)
    string match -qr '^[0-9]+$' -- "$_now"; or return
    set -l _last $__fish_config_bootstrap_pending[1]
    if string match -qr '^[0-9]+$' -- "$_last"
        and test $_last -le $_now
        and test (math $_now - $_last) -lt 86400
        echo "  [first-run] Plugin bootstrap is pending (an earlier attempt failed); it is retried at most once a day. Retry now: set -U __fish_config_bootstrap_pending 0" >&2
        return
    end
    # Stamp BEFORE trying, so a hang or Ctrl-C cannot cause a retry on every
    # start; success erases the marker below.
    set -U __fish_config_bootstrap_pending $_now
    set _retry 1
else
    # Set the flag immediately — before actions — so a mid-run crash doesn't
    # leave the shell in a state that re-triggers everything next session.
    # A failed Fisher bootstrap below is retried by the pending marker (see
    # "Retry a failed bootstrap" above), never by clearing this flag: that
    # would re-print the welcome banner on every retry.
    set -U __fish_config_first_run_complete 1

    #   ──────────────────────────── Man page symlink ──────────────────────────
    # Install fish-config.1 into the user man database once, like an install step.
    # Unconditional: standard enough that no category gate is warranted.
    set -l _man1 ~/.local/share/man/man1
    set -l _src ~/.config/fish/docs/fish-config.1
    if test -f $_src; and not test -L $_man1/fish-config.1
        mkdir -p $_man1
        ln -sf $_src $_man1/fish-config.1
    end

    #   ──────────────────────────── Welcome message ───────────────────────────
    # Printing a first-run welcome banner is opinionated (C6 greeting). The
    # first-run state variable is already set unconditionally above, so
    # disabling the greeting never re-triggers this file.
    if __fish_config_op_enabled (status basename) first-run-greeting
        echo ""
        echo "  Welcome to your fish shell configuration!"
        echo "  Run 'help config' for offline documentation."
        echo "  Run 'fish-deps'   to check and install dependencies."
        echo ""
    end

    #   ─────────────────────── Opinionated auto-exec guard ────────────────────
    # Startup side-effects below (Fisher curl, fisher update, theme apply) are
    # opinionated (C2 auto-execution). The first-run state variable is already
    # set above either way, so disabling auto-exec never re-triggers this file.
    if not __fish_config_op_enabled (status basename) first-run-bootstrap
        return
    end
end

#   ──────────────────────────── Bootstrap Fisher ──────────────────────────
# Fisher is fetched from a PINNED release tag, never the floating `main`
# branch, because the downloaded script is executed. To bump it: pick a tag
# from the Fisher releases page (jorgebucaran/fisher on GitHub), confirm that
# <tag>/functions/fisher.fish resolves, and change _fisher_ref below.
set -l _fisher_ref 4.4.8
set -l _fisher_url https://raw.githubusercontent.com/jorgebucaran/fisher/$_fisher_ref/functions/fisher.fish

# A retry must never block an offline start noticeably: short timeouts there.
set -l _connect_timeout 10
set -l _max_time 30
if test $_retry -eq 1
    set _connect_timeout 3
    set _max_time 10
end

set -l _failed 0 # 1 once any bootstrap step has failed
set -l _run_update 0 # 1 when `fisher update` should run

if not type -q fisher
    test $_retry -eq 0; and echo "  [first-run] Installing Fisher plugin manager..."
    # Download to a file first: `curl | source` reports the status of `source`
    # (0 for empty input), so a failed download looked like a success. Success
    # means curl exited 0 (-f turns HTTP errors into failures), the body is
    # non-empty, it sourced cleanly, and `fisher` is now actually defined.
    set -l _fisher_tmp (mktemp)
    if test -n "$_fisher_tmp"
        and curl -fsSL --connect-timeout $_connect_timeout --max-time $_max_time -o $_fisher_tmp $_fisher_url
        and test -s $_fisher_tmp
        and source $_fisher_tmp
        and type -q fisher
        test $_retry -eq 0; and echo "  [first-run] Fisher installed."
        set _run_update 1
    else
        set _failed 1
        if test $_retry -eq 0
            echo "  [first-run] Fisher install failed (download or load error)." >&2
            echo "  [first-run] Plugins such as sponge (history secret filtering) are NOT installed." >&2
            echo "  [first-run] To retry: set -Ue __fish_config_first_run_complete  # then restart fish" >&2
            echo "  [first-run] Otherwise it is retried automatically on a later start, at most once a day." >&2
        end
    end
    test -n "$_fisher_tmp"; and command rm -f $_fisher_tmp
else if test $_retry -eq 1
    # Fisher is already here (installed by hand, or by a partial update): the
    # outstanding work is the plugin update.
    set _run_update 1
end

if test $_run_update -eq 1
    # Capture both streams so a failure can say why (network, bad plugin
    # ref, a plugin install hook). Success stays silent: the output is
    # only shown on failure. Fisher names the offending plugin in its own
    # "fisher: ..." lines, so the tail of the output is what is relayed.
    set -l _fisher_out (fisher update 2>&1)
    set -l _fisher_rc $status
    if test $_fisher_rc -ne 0
        set _failed 1
        echo "  [first-run] Fisher update failed (exit $_fisher_rc) — run 'fisher update' manually." >&2
        if test (count $_fisher_out) -gt 0
            echo "  [first-run] Last output from Fisher:" >&2
            printf '    %s\n' $_fisher_out[-5..-1] >&2
        end
    end
end

#   ─────────────────────── Record the bootstrap outcome ───────────────────
# Failure leaves the universal marker holding the attempt's epoch time (a retry
# already stamped it above); success erases it. The first-run flag is untouched.
if test $_failed -eq 1
    if test $_retry -eq 0
        set -U __fish_config_bootstrap_pending (command date +%s 2>/dev/null)
    else
        echo "  [first-run] Plugin bootstrap retry failed; trying again in a day. Retry now: set -U __fish_config_bootstrap_pending 0" >&2
    end
else if test $_retry -eq 1
    set -Ue __fish_config_bootstrap_pending
    echo "  [first-run] Plugin bootstrap retry succeeded: Fisher and plugins are installed."
end

# A retry re-runs the bootstrap step only: no theme.
if test $_retry -eq 1
    return
end

#   ───────────────────────────── Apply theme ──────────────────────────────
# Catppuccin Mocha ships with this config as themes/catppuccin-mocha.theme; it is
# always available, and it takes precedence over fish's built-in theme of the
# same name.
if not fish_config theme choose catppuccin-mocha 2>/dev/null
    echo "  [first-run] Could not apply Catppuccin Mocha theme — set manually with 'fish_config theme choose'." >&2
end
