# Copyright (C) 2026 Rootiest
# SPDX-License-Identifier: AGPL-3.0-or-later

# SYNOPSIS
#   __config_settings_draw <cur_row> <cur_scope> <var1> ... <var8>
#
# DESCRIPTION
#   Renders the 16-line config-settings TUI panel to stdout. Panel width and
#   horizontal position are chosen automatically from $COLUMNS each call,
#   so a terminal resize takes effect on the next keypress without any
#   extra bookkeeping. Four width tiers with a 6-col buffer per side:
#
#     COLUMNS ≥ 90 → 78-wide (IW=76, desc=43 chars)
#     COLUMNS ≥ 86 → 74-wide (IW=72, desc=39 chars)
#     COLUMNS ≥ 82 → 70-wide (IW=68, desc=35 chars)
#     COLUMNS  < 82 → 52-wide (IW=50, desc=17 chars)  ← default
#
#   The box is horizontally centered via a left-padding prefix on every
#   output line. \e[16A\e[J erases by line count so the horizontal offset
#   does not interfere with the redraw loop.
#
# ARGUMENTS
#   cur_row    0–7, the currently highlighted row
#   cur_scope  "universal" or "session"
#   var1–var8  Variable names for rows 0–7 (in order per Variable Reference)
#
# RETURNS
#   0  Always
#
# EXAMPLE
#   __config_settings_draw 0 universal \
#       __fish_config_op_aliases __fish_config_op_autoexec \
#       __fish_config_op_overrides __fish_config_op_integrations \
#       __fish_config_op_logging __fish_config_op_greeting \
#       __fish_config_opinionated __fish_user_dots_path
function __config_settings_draw
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

    set -l labels Aliases Auto-exec Overrides Integrations Logging Greeting Master

    # ── Width tier: 6-col buffer per side before stepping up ──────────────
    # IW = inner width (chars between │ │); desc field = IW - 33.
    # All four layouts are exactly 16 lines tall — panel_h in caller stays 16.
    set -l iw 50
    set -l descs \
        "cmd shadows" \
        startup \
        "keys/env/prompt" \
        "terminal coupling" \
        scrollback \
        fish_greeting \
        "disable all"

    if test "$COLUMNS" -ge 90
        set iw 76
        set descs \
            "shadows: ls→eza, cat→bat, cd→z, rm→trash" \
            "Fisher bootstrap, themes, py-venv activate" \
            "vi-mode, bang-bang, PAGER, CDPATH, starship" \
            "Kitty/WezTerm tab/split fns, notifications" \
            "scrollback capture & paru/yay AUR wrappers" \
            "fish_greeting & first-run welcome banner" \
            "master off-switch: overrides all categories"
    else if test "$COLUMNS" -ge 86
        set iw 72
        set descs \
            "ls→eza, cat→bat, cd→zoxide, rm→trash" \
            "Fisher bootstrap, themes, py-venv auto" \
            "vi-mode, bang-bang, PAGER, starship" \
            "Kitty/WezTerm fns, done notifications" \
            "scrollback capture & paru/yay wrappers" \
            "fish_greeting: first-run welcome banner" \
            "master off-switch for all categories"
    else if test "$COLUMNS" -ge 82
        set iw 68
        set descs \
            "ls→eza, cat→bat, cd→z, rm→trash" \
            "Fisher, themes, py-venv activate" \
            "vi-mode, bang-bang, PAGER, starship" \
            "Kitty/WezTerm, done notifications" \
            "scrollback & paru/yay log wrappers" \
            "fish_greeting & first-run banner" \
            "master disable for all categories"
    end

    set -l HBR (string repeat -n $iw '─')

    # ── Center padding ────────────────────────────────────────────────────
    # ponytail: floor division — left margin may be 1 col less than right if gap is odd
    set -l p (string repeat -n (math --scale=0 "max(0, ($COLUMNS - ($iw + 2)) / 2)") ' ')

    # ── Scope tabs ────────────────────────────────────────────────────────
    set -l u_label
    set -l s_label
    if test $cur_scope = universal
        set u_label "$c_hi● Universal$c_reset"
        set s_label "○ Session  "
    else
        set u_label "○ Universal"
        set s_label "$c_hi● Session  $c_reset"
    end

    # ── Top border ────────────────────────────────────────────────────────
    # ┌─ Opinionated Settings (iw-23)×─ ┐  total = iw+2
    printf '%s┌─%s Opinionated Settings %s┐\n' \
        $p $c_head $c_reset(string repeat -n (math $iw - 23) '─')

    # ── Scope tab line ────────────────────────────────────────────────────
    # Inner: " ●/○ Universal  ●/○ Session  " (25) + (iw-40)×space + "Tab to switch  " (15) = iw
    printf '%s│ %s  %s%s│\n' \
        $p $u_label $s_label \
        (string repeat -n (math $iw - 40) ' ')"Tab to switch  "

    # ── Top divider ───────────────────────────────────────────────────────
    printf '%s│%s│\n' $p $HBR

    # ── Category rows 0–5 ─────────────────────────────────────────────────
    for i in (seq 0 5)
        set -l idx   (math $i + 1)
        set -l var   $vars[$idx]
        set -l label $labels[$idx]
        set -l desc  $descs[$idx]

        set -l val (__config_settings_get_val $var $cur_scope)

        # Badge: 7 visible chars, coloured
        set -l badge
        switch $val
            case on
                set badge "$c_ok""     ON$c_reset"
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

        # Label padded to 12, desc padded to (iw-33), right margin 3
        set -l lpad (string pad -r -w 12 -- $label)
        set -l dpad (string pad -r -w (math $iw - 33) -- $desc)

        printf '%s│  %s%s [ %s ]  %s   │\n' $p $curs $lpad $badge $dpad
    end

    # ── Separator before Master ───────────────────────────────────────────
    printf '%s│    %s  │\n' $p (string repeat -n (math $iw - 6) '─')

    # ── Master row (index 6) ──────────────────────────────────────────────
    set -l val (__config_settings_get_val $vars[7] $cur_scope)
    set -l badge
    switch $val
        case on
            set badge "$c_ok""     ON$c_reset"
        case off
            set badge "$c_err""OFF    $c_reset"
        case '*'
            set badge "$c_dim""DEFAULT$c_reset"
    end
    set -l curs "  "
    if test $cur_row -eq 6
        set curs "$c_sel▶$c_reset "
    end
    printf '%s│  %s%s [ %s ]  %s   │\n' \
        $p $curs \
        (string pad -r -w 12 -- Master) \
        $badge \
        (string pad -r -w (math $iw - 33) -- $descs[7])

    # ── Separator before Path Settings ───────────────────────────────────
    printf '%s│    %s  │\n' $p (string repeat -n (math $iw - 6) '─')

    # ── Path row (index 7) — always universal scope ───────────────────────
    set -l path_var $vars[8]
    set -l raw_path (__config_settings_get_val $path_var universal)

    set -l path_badge
    set -l path_dpad
    if test "$raw_path" = DEFAULT
        set path_badge "$c_dim""DEFAULT$c_reset"
        set path_dpad  (string pad -r -w (math $iw - 33) -- "—default—  [U]")
    else
        set path_badge "$c_ok"" PATH  $c_reset"
        set -l max_path (math $iw - 37)
        set -l truncated (string shorten -m $max_path -- "$raw_path")
        set path_dpad (string pad -r -w (math $iw - 33) -- "$truncated [U]")
    end

    set -l path_curs "  "
    if test $cur_row -eq 7
        set path_curs "$c_sel▶$c_reset "
    end

    printf '%s│  %s%s [ %s ]  %s   │\n' \
        $p $path_curs \
        (string pad -r -w 12 -- "Dots Path") \
        $path_badge \
        $path_dpad

    # ── Bottom divider ────────────────────────────────────────────────────
    printf '%s│%s│\n' $p $HBR

    # ── Keybind hint ──────────────────────────────────────────────────────
    # string pad is width-aware (arrows count as 1 column)
    set -l hint " ↑↓/kj move  ←→/hl set  Enter edit path  q quit"
    printf '%s│%s%s%s│\n' $p $c_dim (string pad -r -w $iw -- $hint) $c_reset

    # ── Bottom border ─────────────────────────────────────────────────────
    printf '%s└%s┘\n' $p $HBR
end
