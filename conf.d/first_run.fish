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
if not type -q fisher
    echo "  [first-run] Installing Fisher plugin manager..."
    if curl -sL https://raw.githubusercontent.com/jorgebucaran/fisher/main/functions/fisher.fish | source
        echo "  [first-run] Fisher installed."
        if not fisher update 2>/dev/null
            echo "  [first-run] Fisher update failed — run 'fisher update' manually." >&2
        end
    else
        echo "  [first-run] Fisher install failed — run 'fisher update' manually." >&2
    end
end

#   ───────────────────────────── Apply theme ──────────────────────────────
# Catppuccin Mocha theme ships with this config in themes/; it is always available.
if not fish_config theme choose "Catppuccin Mocha" 2>/dev/null
    echo "  [first-run] Could not apply Catppuccin Mocha theme — set manually with 'fish_config theme choose'." >&2
end
