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
#   Values are changed directionally with the arrow keys (or vim-style h/l)
#   along an OFF ← DEFAULT → ON scale, and apply immediately — no confirm
#   step. Always available regardless of __fish_config_opinionated state.
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
                echo "  $c_flag↑ ↓$c_reset or $c_flag""k j$c_reset    Move cursor up / down"
                echo "  $c_flag← →$c_reset or $c_flag""h l$c_reset    Set value: OFF ← DEFAULT → ON"
                echo "  $c_flag""Tab$c_reset           Switch scope (Universal ↔ Session)"
                echo "  $c_flag""q$c_reset / $c_flag""Esc$c_reset       Exit"
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
    trap 'printf "\e[?25h"; set -g __config_toggle_exit 1' INT

    # ── Initial draw ──────────────────────────────────────
    __config_toggle_draw $cur_row $cur_scope $vars

    # ── Event loop ────────────────────────────────────────
    # __config_toggle_read_key reads a single keypress from /dev/tty in raw
    # mode and returns a normalized token (up/down/tab/space/escape/quit or a
    # literal char). It bypasses fish's `read`, whose line editor swallows Tab
    # and arrow keys and prints a `read> ` prompt — unusable for a TUI.
    while true
        # Check for Ctrl-C signal (trap sets this flag during redraw, when the
        # terminal is briefly back in cooked mode and SIGINT can fire).
        if set -q __config_toggle_exit
            set -eg __config_toggle_exit
            break
        end

        set -l key (__config_toggle_read_key)
        or break   # not a TTY — exit instead of spinning

        switch $key
            case up k
                set cur_row (math "max(0, $cur_row - 1)")
            case down j
                set cur_row (math "min(6, $cur_row + 1)")
            case tab      # Tab — switch scope
                if test $cur_scope = universal
                    set cur_scope session
                else
                    set cur_scope universal
                end
            case right l   # → / l — step toward ON (clamped, no wrap)
                set -l varname $vars[(math $cur_row + 1)]
                set -l cur_val (__config_toggle_get_val $varname $cur_scope)

                # Order: OFF ← DEFAULT → ON
                set -l next_val on
                switch $cur_val
                    case off
                        set next_val DEFAULT
                    case on
                        set next_val on     # already at the right end
                    case '*'   # DEFAULT or unrecognised
                        set next_val on
                end
                __config_toggle_apply $varname $cur_scope $next_val
            case left h   # ← / h — step toward OFF (clamped, no wrap)
                set -l varname $vars[(math $cur_row + 1)]
                set -l cur_val (__config_toggle_get_val $varname $cur_scope)

                # Order: OFF ← DEFAULT → ON
                set -l next_val off
                switch $cur_val
                    case on
                        set next_val DEFAULT
                    case off
                        set next_val off    # already at the left end
                    case '*'   # DEFAULT or unrecognised
                        set next_val off
                end
                __config_toggle_apply $varname $cur_scope $next_val
            case q Q quit escape
                break
        end

        # Redraw in place
        printf '\e[%dA\e[J' $panel_h
        __config_toggle_draw $cur_row $cur_scope $vars
    end

    # ── Cleanup ───────────────────────────────────────────
    trap - INT              # remove the signal handler
    printf '\e[%dA\e[J' $panel_h   # erase the panel
    printf '\e[?25h'        # restore cursor
end
