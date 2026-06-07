# Copyright (C) 2026 Rootiest
# SPDX-License-Identifier: AGPL-3.0-or-later

#          ╭──────────────────────────────────────────────────────────╮
#          │                First-Run Initialization                  │
#          ╰──────────────────────────────────────────────────────────╯
#
# Runs exactly once on the first interactive fish session after install.
# To reset for testing, run: set -Ue __fish_config_first_run_complete

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

#   ──────────────────────────── Welcome message ───────────────────────────
echo ""
echo "  Welcome to your fish shell configuration!"
echo "  Run 'help config' for offline documentation."
echo "  Run 'fish-deps'   to check and install dependencies."
echo ""

#   ──────────────────────────── Bootstrap Fisher ──────────────────────────
if not type -q fisher
    echo "  [first-run] Installing Fisher plugin manager..."
    if curl -sL https://raw.githubusercontent.com/jorgebucaran/fisher/main/functions/fisher.fish | source
        echo "  [first-run] Fisher installed."
        if not fisher update 2>/dev/null
            echo "  [first-run] Plugin sync failed — run 'fisher update' manually." >&2
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
