# Copyright (C) 2026 Rootiest
# SPDX-License-Identifier: AGPL-3.0-or-later

#          ╭──────────────────────────────────────────────────────────╮
#          │                First-Run Initialization                  │
#          ╰──────────────────────────────────────────────────────────╯
#
# Runs exactly once on the first interactive fish session after install.
# To reset for testing, run: set -Ue __fish_config_first_run_complete
#
# COMPONENT
#   site first-run-greeting: greeting/first-run
#   site first-run-bootstrap: autoexec/plugin-management

# Exit early in non-interactive shells (scripts, completions, subshells)
if not status is-interactive
    return
end

# Skip if this shell has already been initialized
if set -q __fish_config_first_run_complete
    return
end

# Set the flag immediately — before actions — so a mid-run crash doesn't
# leave the shell in a state that re-triggers everything next session.
# Trade-off: a failed Fisher bootstrap below is therefore NOT retried
# automatically (an automatic retry would re-print the welcome banner and
# block shell startup on the network every session while offline). The
# failure message tells the user how to retry.
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

#   ──────────────────────────── Bootstrap Fisher ──────────────────────────
# Fisher is fetched from a PINNED release tag, never the floating `main`
# branch, because the downloaded script is executed. To bump it: pick a tag
# from the Fisher releases page (jorgebucaran/fisher on GitHub), confirm that
# <tag>/functions/fisher.fish resolves, and change _fisher_ref below.
set -l _fisher_ref 4.4.8
set -l _fisher_url https://raw.githubusercontent.com/jorgebucaran/fisher/$_fisher_ref/functions/fisher.fish

if not type -q fisher
    echo "  [first-run] Installing Fisher plugin manager..."
    # Download to a file first: `curl | source` reports the status of `source`
    # (0 for empty input), so a failed download looked like a success. Success
    # means curl exited 0 (-f turns HTTP errors into failures), the body is
    # non-empty, it sourced cleanly, and `fisher` is now actually defined.
    set -l _fisher_tmp (mktemp)
    if test -n "$_fisher_tmp"
        and curl -fsSL --connect-timeout 10 --max-time 30 -o $_fisher_tmp $_fisher_url
        and test -s $_fisher_tmp
        and source $_fisher_tmp
        and type -q fisher
        echo "  [first-run] Fisher installed."
        if not fisher update 2>/dev/null
            echo "  [first-run] Fisher update failed — run 'fisher update' manually." >&2
        end
    else
        echo "  [first-run] Fisher install failed (download or load error)." >&2
        echo "  [first-run] Plugins such as sponge (history secret filtering) are NOT installed." >&2
        echo "  [first-run] To retry: set -Ue __fish_config_first_run_complete  # then restart fish" >&2
    end
    test -n "$_fisher_tmp"; and command rm -f $_fisher_tmp
end

#   ───────────────────────────── Apply theme ──────────────────────────────
# Catppuccin Mocha ships with this config as themes/catppuccin-mocha.theme; it is
# always available, and it takes precedence over fish's built-in theme of the
# same name.
if not fish_config theme choose catppuccin-mocha 2>/dev/null
    echo "  [first-run] Could not apply Catppuccin Mocha theme — set manually with 'fish_config theme choose'." >&2
end
