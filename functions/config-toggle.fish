# Copyright (C) 2026 Rootiest
# SPDX-License-Identifier: AGPL-3.0-or-later

# SYNOPSIS
#   config-toggle [-h | --help]
#
# DESCRIPTION
#   Opens an interactive full-screen TUI for toggling the six opinionated
#   component categories (C1–C6) and the master disable variable without
#   having to remember variable names. Two scope tabs allow independent
#   per-scope configuration:
#
#     Universal — persists across all sessions (set -U / set -Ue)
#     Session   — active for the current shell only (set -g / set -eg)
#
#   Changes apply immediately on each Space keypress — no confirm step.
#   Always available regardless of __fish_config_opinionated state.
#
# ARGUMENTS
#   -h, --help  Print usage and exit
#
# RETURNS
#   0  Exited normally (q or Escape pressed)
#   1  Unknown flag passed
#
# EXAMPLE
#   config-toggle
function config-toggle --description 'Interactive TUI for toggling opinionated component settings'
    set -l c_head  (set_color --bold cyan)
    set -l c_cmd   (set_color --bold white)
    set -l c_flag  (set_color yellow)
    set -l c_dim   (set_color brblack)
    set -l c_err   (set_color red)
    set -l c_reset (set_color normal)

    # ── Argument parsing ──────────────────────────────────
    for arg in $argv
        switch $arg
            case -h --help
                echo "$c_head""Usage:$c_reset $c_cmd""config-toggle$c_reset $c_flag""[-h]$c_reset"
                echo
                echo "  Interactive TUI for toggling opinionated component categories."
                echo "  Changes apply immediately — no confirm step required."
                echo
                echo "$c_head""Navigation:$c_reset"
                echo "  $c_flag↑ ↓$c_reset or $c_flag""j k$c_reset    Move cursor up / down"
                echo "  $c_flag""Space$c_reset         Cycle: ON → OFF → DEFAULT → ON"
                echo "  $c_flag""Tab$c_reset           Switch scope (Universal ↔ Session)"
                echo "  $c_flag""q$c_reset / $c_flag""Escape$c_reset    Exit"
                echo
                echo "$c_head""Scopes:$c_reset"
                echo "  $c_flag""Universal$c_reset   Persistent across all sessions ($c_dim""set -U$c_reset)"
                echo "  $c_flag""Session$c_reset     Current session only ($c_dim""set -g$c_reset)"
                return 0
            case '*'
                echo "$c_err""Unknown option: $arg$c_reset" >&2
                echo "Run $c_cmd""config-toggle --help$c_reset for usage." >&2
                return 1
        end
    end

    # ── Variable list (matches Panel Layout Reference) ────
    set -l vars \
        __fish_config_op_aliases \
        __fish_config_op_autoexec \
        __fish_config_op_overrides \
        __fish_config_op_integrations \
        __fish_config_op_logging \
        __fish_config_op_greeting \
        __fish_config_opinionated

    set -l cur_row   0           # 0–6
    set -l cur_scope universal   # or "session"
    set -l panel_h   14          # total panel lines

    # ── Terminal setup ────────────────────────────────────
    printf '\e[?25l'             # hide cursor
    trap 'printf "\e[?25h"; printf "\n"' INT

    # ── Initial draw ──────────────────────────────────────
    __config_toggle_draw $cur_row $cur_scope $vars

    # ── Event loop ────────────────────────────────────────
    while true
        read -k 1 -l key

        switch $key
            case \e
                # Arrow key: ESC [ A/B — read next 2 chars one at a time.
                # Terminal sends escape sequences as an atomic burst, so
                # read -k 1 returns each char immediately.
                # If the char after ESC is not '[', treat as bare Escape → quit.
                read -k 1 -l ch1
                if test "$ch1" != '['
                    # Bare Escape (or unrecognised sequence) — exit
                    break
                end
                read -k 1 -l ch2
                switch $ch2
                    case A   # Up arrow
                        set cur_row (math "max(0, $cur_row - 1)")
                    case B   # Down arrow
                        set cur_row (math "min(6, $cur_row + 1)")
                end

            case k
                set cur_row (math "max(0, $cur_row - 1)")
            case j
                set cur_row (math "min(6, $cur_row + 1)")

            case \t   # Tab — switch scope
                if test $cur_scope = universal
                    set cur_scope session
                else
                    set cur_scope universal
                end

            case q Q
                break
        end

        # Redraw in place
        printf '\e[%dA\e[J' $panel_h
        __config_toggle_draw $cur_row $cur_scope $vars
    end

    # ── Cleanup ───────────────────────────────────────────
    printf '\e[?25h'   # restore cursor
end
