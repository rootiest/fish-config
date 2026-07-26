# Copyright (C) 2026 Rootiest
# SPDX-License-Identifier: AGPL-3.0-or-later

# CATEGORY
#   14-miscellaneous
#
# SYNOPSIS
#   config-settings [-h | --help]
#
# DESCRIPTION
#   Opens an interactive full-screen TUI for managing fish config settings
#   across four pages, without having to type or remember variable names:
#
#     Universal — opinionated-category toggles (C1–C6) + master, persistent (set -U)
#     Session   — the same toggles, current shell only (set -g)
#     Sponge    — sponge history-scrubbing settings: delay, successful exit
#                 codes, purge-only-on-exit, allow-previously-successful, and
#                 extra sensitive variable-name tokens
#     Paths     — scrollback log directory, scrollback max files, the user-dots
#                 path, and the user-dots convenience symlink toggle (Dots link)
#
#   Toggle rows use ← / → (or h / l) to step OFF ← DEFAULT → ON; DEFAULT erases
#   the variable so the master switch / built-in default applies. Value rows
#   (Sponge, Paths) use Enter to edit inline; ← / h clears to default. List rows
#   (e.g. Extra secret, OK codes) accept values separated by commas and/or
#   whitespace — "A, B", "A,B" and "A B" all yield the same two entries.
#   Tab / Shift-Tab cycle forward / backward through pages.
#   Changes apply immediately — no confirm step. Always available regardless of
#   __fish_config_opinionated state.
#
#   The Sponge and Paths pages always write universal variables — these are
#   persistent, set-and-forget settings with no per-session scope. Editing a
#   scrollback row updates both the __fish_scrollback_history_* source-of-truth
#   variables and the exported SCROLLBACK_HISTORY_* mirrors, so the AUR/tmux/
#   zellij log wrappers (which read the exported names) see the change in the
#   running session.
#
#   The panel adapts to the terminal width automatically, selecting from four
#   layout tiers (with a 6-column buffer on each side before stepping up to the
#   next tier) and horizontally centering the box. The panel redraws within
#   ~0.3 s of a terminal resize with no keypress required.
#
#     COLUMNS >= 90  →  78-wide panel (most detail)
#     COLUMNS >= 86  →  74-wide panel
#     COLUMNS >= 82  →  70-wide panel
#     COLUMNS  < 82  →  52-wide panel (default)
#
#   Navigation:
#     ↑ ↓ / k j     Move cursor
#     ← → / h l     Toggle rows: OFF ← DEFAULT → ON
#     ←  / h        Value rows: clear to default
#     Enter         Value rows: edit inline (Sponge / Paths pages)
#     Tab / S-Tab   Next / previous page
#     q / Escape    Exit
#
# ARGUMENTS
#   -h, --help  Print usage and exit
#
# RETURNS
#   0  Exited normally (q or Escape pressed)
#   1  Unknown flag passed
#
# EXAMPLE
#   config-settings
function config-settings --description 'Interactive TUI for managing fish config settings'
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
                echo "$c_head""Usage:$c_reset $c_cmd""config-settings$c_reset $c_flag""[-h]$c_reset"
                echo
                echo "  Interactive TUI for managing fish config settings."
                echo "  Changes apply immediately — no confirm step required."
                echo
                echo "$c_head""Navigation:$c_reset"
                echo "  $c_flag↑ ↓$c_reset or $c_flag""k j$c_reset    Move cursor up / down"
                echo "  $c_flag← →$c_reset or $c_flag""h l$c_reset    Toggle pages: OFF ← DEFAULT → ON"
                echo "  $c_flag""Enter$c_reset         Edit value (Sponge / Paths pages)"
                echo "  $c_flag← / h$c_reset         Clear value to default (value rows)"
                echo "  $c_flag""Tab / S-Tab$c_reset   Next / previous page"
                echo "  $c_flag""q$c_reset / $c_flag""Esc$c_reset       Exit"
                echo
                echo "$c_head""Pages:$c_reset"
                echo "  $c_flag""Universal$c_reset   Toggles, persistent ($c_dim""set -U$c_reset)"
                echo "  $c_flag""Session$c_reset     Toggles, this shell ($c_dim""set -g$c_reset)"
                echo "  $c_flag""Sponge$c_reset      sponge history-scrubbing settings"
                echo "  $c_flag""Paths$c_reset       scrollback & user-dots paths"
                return 0
            case '*'
                echo "$c_err""Unknown option: $arg$c_reset" >&2
                echo "Run $c_cmd""config-settings --help$c_reset for usage." >&2
                return 1
        end
    end

    # ── Toggle-page variables (rows 0–6: 6 categories + master) ───────────
    set -l toggle_vars \
        __fish_config_op_aliases \
        __fish_config_op_autoexec \
        __fish_config_op_overrides \
        __fish_config_op_integrations \
        __fish_config_op_logging \
        __fish_config_op_greeting \
        __fish_config_opinionated

    # ── Value-page row metadata (parallel: var / type) ────────────────────
    set -l sponge_vars sponge_delay sponge_purge_only_on_exit sponge_allow_previously_successful sponge_successful_exit_codes __fish_sponge_extra_sensitive
    set -l sponge_types int bool bool list list
    set -l sponge_labels Delay "Purge@exit" "Allow prev" "OK codes" "Extra secret"
    set -l paths_vars __fish_scrollback_history_dir __fish_scrollback_history_max_files __fish_user_dots_path __fish_user_dots_symlink
    set -l paths_types path int path bool
    set -l paths_labels "Log dir" "Log max" "Dots path" "Dots link"

    # Reset/blank-edit target for each value row. A non-empty entry is written
    # verbatim (sponge reads sponge_delay / sponge_successful_exit_codes with no
    # fallback, so they must never be left unset); an empty entry erases the var
    # so its own built-in default applies (scrollback/dots paths and the
    # extra-sensitive list all tolerate being unset). Bool rows are not reset
    # through this path — they are a 2-state true/false with no unset state.
    set -l sponge_defaults 2 '' '' 0 ''
    set -l paths_defaults '' '' '' ''

    # Rows per page index 0..3
    set -l page_rows 7 7 5 4

    set -l cur_page  0           # 0=Universal 1=Session 2=Sponge 3=Paths
    set -l cur_row   0
    set -l panel_h   16
    set -l last_cols $COLUMNS

    # ── Terminal setup ────────────────────────────────────
    printf '\e[?25l'             # hide cursor
    trap 'printf "\e[?25h"; set -g __config_settings_exit 1' INT

    # ── Draw dispatch (page 0/1 = toggle table; 2/3 = value page) ─────────
    function __cs_dispatch_draw --no-scope-shadowing
        switch $cur_page
            case 0
                __config_settings_draw $cur_row universal $toggle_vars
            case 1
                __config_settings_draw $cur_row session $toggle_vars
            case 2
                __config_settings_draw_value $cur_row sponge
            case 3
                __config_settings_draw_value $cur_row paths
        end
    end
    __cs_dispatch_draw

    # ── Event loop ────────────────────────────────────────
    # __config_settings_read_key reads a single keypress from /dev/tty in raw
    # mode and returns a normalized token (up/down/tab/space/escape/quit or a
    # literal char). It bypasses fish's `read`, whose line editor swallows Tab
    # and arrow keys and prints a `read> ` prompt — unusable for a TUI.
    while true
        # Check for Ctrl-C signal (trap sets this flag during redraw, when the
        # terminal is briefly back in cooked mode and SIGINT can fire).
        if set -q __config_settings_exit
            set -eg __config_settings_exit
            break
        end

        set -l key (__config_settings_read_key)
        or break   # not a TTY — exit instead of spinning

        set -l did_redraw 0

        switch $key
            case up k
                set cur_row (math "max(0, $cur_row - 1)")
            case down j
                # Hoist the page index: fish cannot expand a command-substitution
                # index inside a quoted math string.
                set -l pidx (math $cur_page + 1)
                set cur_row (math "min($page_rows[$pidx] - 1, $cur_row + 1)")
            case tab
                set cur_page (math "($cur_page + 1) % 4")
                set cur_row 0
            case backtab
                set cur_page (math "($cur_page + 3) % 4")
                set cur_row 0
            case right l
                if test $cur_page -le 1
                    # Toggle page: step toward ON
                    set -l scope universal
                    test $cur_page -eq 1; and set scope session
                    set -l varname $toggle_vars[(math $cur_row + 1)]
                    set -l cur_val (__config_settings_get_val $varname $scope)
                    set -l next_val on
                    test "$cur_val" = off; and set next_val DEFAULT
                    __config_settings_apply $varname $scope $next_val
                else
                    # Value pages: bool rows are 2-state (true/false). → sets
                    # true. Sponge reads its bools with no fallback; the Paths
                    # "Dots link" bool drives __fish_user_dots_link on change.
                    set -l v_vars $sponge_vars
                    set -l v_types $sponge_types
                    if test $cur_page -eq 3
                        set v_vars $paths_vars
                        set v_types $paths_types
                    end
                    set -l ridx (math $cur_row + 1)
                    if test "$v_types[$ridx]" = bool
                        set -U $v_vars[$ridx] true 2>/dev/null
                        test "$v_vars[$ridx]" = __fish_user_dots_symlink
                            and __fish_user_dots_link
                    end
                end
            case left h
                if test $cur_page -le 1
                    set -l scope universal
                    test $cur_page -eq 1; and set scope session
                    set -l varname $toggle_vars[(math $cur_row + 1)]
                    set -l cur_val (__config_settings_get_val $varname $scope)
                    set -l next_val off
                    test "$cur_val" = on; and set next_val DEFAULT
                    __config_settings_apply $varname $scope $next_val
                else
                    # Value pages: bool rows set false; other value rows reset to
                    # their default (a literal value, or erase when the var
                    # tolerates being unset — see sponge_defaults/paths_defaults).
                    set -l v_vars $sponge_vars
                    set -l v_types $sponge_types
                    set -l v_defaults $sponge_defaults
                    if test $cur_page -eq 3
                        set v_vars $paths_vars
                        set v_types $paths_types
                        set v_defaults $paths_defaults
                    end
                    set -l ridx (math $cur_row + 1)
                    set -l varname $v_vars[$ridx]
                    set -l vtype $v_types[$ridx]
                    if test "$vtype" = bool
                        set -U $varname false 2>/dev/null
                        test "$varname" = __fish_user_dots_symlink
                            and __fish_user_dots_link
                    else
                        __config_settings_set_value $varname $vtype "$v_defaults[$ridx]"
                    end
                end
            case enter
                if test $cur_page -ge 2
                    set -l v_vars $sponge_vars
                    set -l v_types $sponge_types
                    set -l v_defaults $sponge_defaults
                    if test $cur_page -eq 3
                        set v_vars $paths_vars
                        set v_types $paths_types
                        set v_defaults $paths_defaults
                    end
                    set -l ridx (math $cur_row + 1)
                    set -l varname $v_vars[$ridx]
                    set -l vtype $v_types[$ridx]
                    # Only path/int/list rows are editable; bool rows toggle with ←/→.
                    if test "$vtype" != toggle -a "$vtype" != bool
                        # Inline editor: edit in-place in the row's value field
                        # using the raw key reader — no fish `read` / `read>`
                        # prompt, and the panel cleans itself up on exit. The
                        # buffer is pre-filled with the current value; clearing it
                        # and pressing Enter reverts to the row's default.
                        set -l page sponge
                        test $cur_page -eq 3; and set page paths
                        set -l buf (__config_settings_get_raw $varname)
                        test "$buf" = DEFAULT; and set buf ""
                        set -l committed 0
                        while true
                            set -l pml (math --scale=0 "($last_cols + 78) / 2")
                            set -l eh (math --scale=0 "$panel_h * max(1, ceil($pml / $COLUMNS))")
                            printf '\e[%dA\e[J' $eh
                            set last_cols $COLUMNS
                            __config_settings_draw_value $cur_row $page edit "$buf"

                            set -l ek (__config_settings_read_key)
                            or break
                            switch $ek
                                case enter
                                    set committed 1
                                    break
                                case escape
                                    break
                                case backspace
                                    set buf (string sub -s 1 -e -1 -- "$buf")
                                case space
                                    set buf "$buf "
                                case up down left right tab backtab quit ''
                                    # ignored while editing
                                case '*'
                                    set buf "$buf$ek"
                            end
                        end
                        if test $committed -eq 1
                            # Empty buffer reverts to the row default (a value, or
                            # erase when the var tolerates being unset).
                            if test -n "$buf"
                                __config_settings_set_value $varname $vtype "$buf"
                            else
                                __config_settings_set_value $varname $vtype "$v_defaults[$ridx]"
                            end
                        end
                        # Redraw the normal panel in place of the editor.
                        set -l pml (math --scale=0 "($last_cols + 78) / 2")
                        set -l eh (math --scale=0 "$panel_h * max(1, ceil($pml / $COLUMNS))")
                        printf '\e[%dA\e[J' $eh
                        set last_cols $COLUMNS
                        __cs_dispatch_draw
                        set did_redraw 1
                    end
                end
            case q Q quit escape
                break
        end

        # Skip redraw entirely when the key reader timed out with no resize
        if test -z "$key" -a "$COLUMNS" = "$last_cols"
            continue
        end

        # Skip redraw if the Enter handler already redrew (e.g. after path edit)
        if test $did_redraw -eq 1
            continue
        end

        # Wrap-aware erase: a panel drawn on a wider terminal has longer lines
        # (due to center-padding) that wrap into extra physical rows when the
        # terminal narrows. 78 = widest box (IW=76+2); the formula gives the
        # worst-case old line width for any tier drawn at last_cols.
        set -l prev_max_lw (math --scale=0 "($last_cols + 78) / 2")
        set -l erase_h (math --scale=0 "$panel_h * max(1, ceil($prev_max_lw / $COLUMNS))")
        printf '\e[%dA\e[J' $erase_h
        set last_cols $COLUMNS
        __cs_dispatch_draw
    end

    # ── Cleanup ───────────────────────────────────────────
    trap - INT              # remove the signal handler
    set -l prev_max_lw (math --scale=0 "($last_cols + 78) / 2")
    set -l erase_h (math --scale=0 "$panel_h * max(1, ceil($prev_max_lw / $COLUMNS))")
    printf '\e[%dA\e[J' $erase_h   # erase the panel (wrap-aware)
    printf '\e[?25h'        # restore cursor
    functions --erase __cs_dispatch_draw
end
