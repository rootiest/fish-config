# Copyright (C) 2026 Rootiest
# SPDX-License-Identifier: AGPL-3.0-or-later

# SYNOPSIS
#   __config_toggle_draw <cur_row> <cur_scope> <var1> ... <var7>
#
# DESCRIPTION
#   Renders the 14-line config-toggle TUI panel to stdout. Intended to be
#   called once on startup, then again after each keypress preceded by
#   `printf '\e[14A\e[J'` (cursor-up 14 lines + clear-to-end) to redraw
#   in place. Does not move the cursor — caller manages positioning.
#
# ARGUMENTS
#   cur_row    0–6, the currently highlighted row
#   cur_scope  "universal" or "session"
#   var1–var7  Variable names for rows 0–6 (in order per Variable Reference)
#
# RETURNS
#   0  Always
#
# EXAMPLE
#   __config_toggle_draw 0 universal \
#       __fish_config_op_aliases __fish_config_op_autoexec \
#       __fish_config_op_overrides __fish_config_op_integrations \
#       __fish_config_op_logging __fish_config_op_greeting \
#       __fish_config_opinionated
function __config_toggle_draw
    set -l cur_row   $argv[1]
    set -l cur_scope $argv[2]
    set -l vars      $argv[3..]

    set -l c_ok    (set_color green)
    set -l c_err   (set_color red)
    set -l c_dim   (set_color brblack)
    set -l c_sel   (set_color --bold magenta)
    set -l c_hi    (set_color --bold white)
    set -l c_head  (set_color --bold cyan)
    set -l c_reset (set_color normal)

    set -l labels  Aliases Auto-exec Overrides Integrations Logging Greeting Master
    set -l descs   "cmd shadows" startup "keys/env/prompt" "terminal coupling" scrollback fish_greeting "disable all"

    # Panel dimensions
    set -l IW 50   # inner width (chars between │ │)
    set -l HBR (string repeat -n $IW '─')

    # ── Scope tabs ────────────────────────────────────────
    set -l u_label
    set -l s_label
    if test $cur_scope = universal
        set u_label "$c_hi● Universal$c_reset"
        set s_label "○ Session  "
    else
        set u_label "○ Universal"
        set s_label "$c_hi● Session  $c_reset"
    end

    # ── Top border ────────────────────────────────────────
    # Visible: ┌(1) ─(1) space(1) "Opinionated Settings"(20) space(1) N×─ ┐(1) = 52
    # N = 52 - 25 = 27 = IW - 23
    printf '┌─%s Opinionated Settings %s┐\n' \
        $c_head $c_reset(string repeat -n (math $IW - 23) '─')

    # ── Scope tab line ────────────────────────────────────
    # Visible inner (50): space(1) + u_label(11) + 2spaces + s_label(11) + 10spaces + "Tab to switch  "(15) = 50
    printf '│ %s  %s%s│\n' \
        $u_label $s_label \
        (string repeat -n 10 ' ')"Tab to switch  "

    # ── Top divider ───────────────────────────────────────
    printf '│%s│\n' $HBR

    # ── Category rows 0–5 ─────────────────────────────────
    for i in (seq 0 5)
        set -l idx    (math $i + 1)
        set -l var    $vars[$idx]
        set -l label  $labels[$idx]
        set -l desc   $descs[$idx]

        set -l val (__config_toggle_get_val $var $cur_scope)

        # Badge: 7 visible chars, coloured
        set -l badge
        switch $val
            case on
                set badge "$c_ok""ON     $c_reset"
            case off
                set badge "$c_err""OFF    $c_reset"
            case '*'
                set badge "$c_dim""DEFAULT$c_reset"
        end

        # Cursor: 2 visible chars
        set -l curs "  "
        if test $i -eq $cur_row
            set curs "$c_sel▶$c_reset "
        end

        # Label padded to 12, desc padded to 17, right margin 3
        set -l lpad (string pad -r -w 12 -- $label)
        set -l dpad (string pad -r -w 17 -- $desc)

        printf '│  %s%s [ %s ]  %s   │\n' $curs $lpad $badge $dpad
    end

    # ── Separator before Master ───────────────────────────
    printf '│    %s  │\n' (string repeat -n (math $IW - 6) '─')

    # ── Master row (index 6) ──────────────────────────────
    set -l val (__config_toggle_get_val $vars[7] $cur_scope)
    set -l badge
    switch $val
        case on
            set badge "$c_ok""ON     $c_reset"
        case off
            set badge "$c_err""OFF    $c_reset"
        case '*'
            set badge "$c_dim""DEFAULT$c_reset"
    end
    set -l curs "  "
    if test $cur_row -eq 6
        set curs "$c_sel▶$c_reset "
    end
    printf '│  %s%s [ %s ]  %s   │\n' \
        $curs \
        (string pad -r -w 12 -- Master) \
        $badge \
        (string pad -r -w 17 -- "disable all")

    # ── Bottom divider ────────────────────────────────────
    printf '│%s│\n' $HBR

    # ── Keybind hint ──────────────────────────────────────
    printf '│  %s↑↓/jk: move  Space: cycle  Tab: scope  q: quit%s  │\n' \
        $c_dim $c_reset

    # ── Bottom border ─────────────────────────────────────
    printf '└%s┘\n' $HBR
end
