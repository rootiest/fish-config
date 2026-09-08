# Copyright (C) 2026 Rootiest
# SPDX-License-Identifier: AGPL-3.0-or-later

# SYNOPSIS
#   __config_settings_draw <cur_row> <cur_scope> <var1> ... <var7>
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
#   cur_row    0–6, the currently highlighted row
#   cur_scope  "universal" or "session"
#   var1–var7  Variable names for rows 0–6 (6 categories + master)
#
# EXIT STATUS
#   0  Always
#
# EXAMPLE
#   __config_settings_draw 0 universal \
#       __fish_config_op_aliases __fish_config_op_autoexec \
#       __fish_config_op_overrides __fish_config_op_integrations \
#       __fish_config_op_logging __fish_config_op_greeting \
#       __fish_config_opinionated
function __config_settings_draw
    set -l cur_row   $argv[1]
    set -l cur_scope $argv[2]
    set -l vars      $argv[3..]

    set -l c_dim (set_color brblack)
    set -l c_head (set_color --bold cyan)
    set -l c_reset (set_color normal)

    set -l labels Aliases Auto-exec Overrides Integrations Logging Greeting Master

    # ── Width tier ────────────────────────────────────────────────────────
    # The tier thresholds live in __config_settings_frame; this file only
    # chooses which hand-authored description set goes with the width.
    # IW = inner width (chars between │ │); desc field = IW - 33.
    # All four layouts are exactly 16 lines tall — panel_h in caller stays 16.
    # Descriptions are authored to fit their field exactly at every tier
    # (43/43, 39/39, 35/35, 17/17), which is why the rows below pass `pad`
    # and not `cut` -- see the NOTES in __config_settings_frame.
    set -l iw (__config_settings_frame width)
    set -l descs \
        "cmd shadows" \
        startup \
        "keys/env/prompt" \
        "terminal coupling" \
        scrollback \
        fish_greeting \
        "disable all"

    switch $iw
        case 76
            set descs \
                "shadows: ls→eza, cat→bat, cd→z, rm→trash" \
                "Fisher bootstrap, themes, py-venv activate" \
                "vi-mode, bang-bang, PAGER, CDPATH, starship" \
                "Kitty/WezTerm tab/split fns, notifications" \
                "scrollback capture & paru/yay AUR wrappers" \
                "fish_greeting & first-run welcome banner" \
                "master off-switch: overrides all categories"
        case 72
            set descs \
                "ls→eza, cat→bat, cd→zoxide, rm→trash" \
                "Fisher bootstrap, themes, py-venv auto" \
                "vi-mode, bang-bang, PAGER, starship" \
                "Kitty/WezTerm fns, done notifications" \
                "scrollback capture & paru/yay wrappers" \
                "fish_greeting: first-run welcome banner" \
                "master off-switch for all categories"
        case 68
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

    # ── Top border ────────────────────────────────────────────────────────
    # ┌─ Opinionated Settings (iw-23)×─ ┐  total = iw+2
    __config_settings_frame title $iw $p "$c_head Opinionated Settings $c_reset"

    # ── Page-tab header ───────────────────────────────────────────────────
    set -l active_idx 0
    if test $cur_scope = session
        set active_idx 1
    end
    printf '%s│%s│\n' $p (__config_settings_pagetab $active_idx $iw)

    # ── Top divider ───────────────────────────────────────────────────────
    printf '%s│%s│\n' $p $HBR

    # ── Category rows 0–5 ─────────────────────────────────────────────────
    # Label field 12 wide; the description field falls out of it inside the
    # frame (field_w = iw - 21 - label_w = iw - 33). `pad`, not `cut`: these
    # descriptions are authored per tier to fit exactly, so truncating them
    # would be a silent no-op that discards that property.
    for i in (seq 0 5)
        set -l idx (math $i + 1)
        set -l val (__config_settings_get_val $vars[$idx] $cur_scope)
        __config_settings_frame row $iw $p \
            (__config_settings_frame cursor $i $cur_row) \
            $labels[$idx] 12 \
            (__config_settings_frame badge $val) \
            $descs[$idx] pad
    end

    # ── Separator before Master ───────────────────────────────────────────
    printf '%s│    %s  │\n' $p (string repeat -n (math $iw - 6) '─')

    # ── Master row (index 6) ──────────────────────────────────────────────
    set -l val (__config_settings_get_val $vars[7] $cur_scope)
    __config_settings_frame row $iw $p \
        (__config_settings_frame cursor 6 $cur_row) \
        Master 12 \
        (__config_settings_frame badge $val) \
        $descs[7] pad

    # ── Filler (Dots Path moved to the Paths page) ────────────────────────
    printf '%s│  %s%s│\n' $p \
        "$c_dim→ Tab for Sponge & Path settings$c_reset" \
        (string repeat -n (math $iw - 34) ' ')
    printf '%s│%s│\n' $p (string repeat -n $iw ' ')

    # ── Bottom divider ────────────────────────────────────────────────────
    printf '%s│%s│\n' $p $HBR

    # ── Keybind hint ──────────────────────────────────────────────────────
    # string pad is width-aware (arrows count as 1 column)
    set -l hint " ↑↓/kj move ←→/hl set Enter sub-cats Tab pg q quit"
    printf '%s│%s%s%s│\n' $p $c_dim (string pad -r -w $iw -- $hint) $c_reset

    # ── Bottom border ─────────────────────────────────────────────────────
    printf '%s└%s┘\n' $p $HBR
end
