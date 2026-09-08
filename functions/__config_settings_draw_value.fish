# Copyright (C) 2026 Rootiest
# SPDX-License-Identifier: AGPL-3.0-or-later

# SYNOPSIS
#   __config_settings_draw_value <cur_row> <page>
#
# DESCRIPTION
#   Renders a config-settings value page (Sponge or Paths) as exactly 16
#   lines, matching the box geometry of the opinionated toggle page so the
#   caller's wrap-aware erase (panel_h=16) is unchanged. Each row shows a
#   label, a badge, and the variable's current value (or its default hint).
#   Toggle-type rows (the two sponge booleans) reuse the ON/OFF/DEFAULT badge;
#   value rows (path/int/list/string) show a type badge and the live value.
#
#   Page width follows the same $COLUMNS tiers as the toggle page for a
#   consistent look; exact width is not required for the erase (the erase
#   over-clears to end of screen using the 78-col worst case).
#
# ARGUMENTS
#   cur_row  0-based highlighted row within the page
#   page     "sponge" or "paths"
#
# EXIT STATUS
#   0  Always
#
# EXAMPLE
#   __config_settings_draw_value 0 sponge
function __config_settings_draw_value
    set -l cur_row $argv[1]
    set -l page    $argv[2]
    # Inline-edit state: when argv[3] is "edit", the cur_row field renders the
    # live input buffer (argv[4]) with a caret instead of its stored value.
    set -l edit_mode $argv[3]
    set -l edit_buf  $argv[4]

    __fish_palette

    # ── Page row metadata (parallel lists) ────────────────────────────────
    set -l title
    set -l vars
    set -l labels
    set -l types
    set -l hints     # default hint shown when unset
    set -l active_idx
    if test $page = sponge
        set title "Sponge Settings"
        set active_idx 2
        set vars  sponge_delay sponge_purge_only_on_exit sponge_allow_previously_successful sponge_successful_exit_codes __fish_sponge_extra_sensitive
        set labels Delay "Purge@exit" "Allow prev" "OK codes" "Extra secret"
        set types  int bool bool list list
        set hints  2 false true 0 "(none)"
    else
        set title "Path Settings"
        set active_idx 3
        set vars  __fish_scrollback_history_dir __fish_scrollback_history_max_files __fish_user_dots_path __fish_user_dots_symlink
        set labels "Log dir" "Log max" "Dots path" "Dots link"
        set types  path int path bool
        set hints  "~/.terminal_history" 100 "(default)" on
    end
    set -l nrows (count $vars)

    # ── Width tier (same thresholds as the toggle page) ───────────────────
    set -l iw (__config_settings_frame width)
    set -l HBR (string repeat -n $iw '─')
    set -l p (string repeat -n (math --scale=0 "max(0, ($COLUMNS - ($iw + 2)) / 2)") ' ')

    # ── Line 1: top border with title ─────────────────────────────────────
    __config_settings_frame title $iw $p "$c_head $title$c_reset "

    # ── Line 2: page-tab header ───────────────────────────────────────────
    printf '%s│%s│\n' $p (__config_settings_pagetab $active_idx $iw)

    # ── Line 3: divider ───────────────────────────────────────────────────
    printf '%s│%s│\n' $p $HBR

    # ── Value rows ────────────────────────────────────────────────────────
    for i in (seq 0 (math $nrows - 1))
        set -l idx   (math $i + 1)
        set -l var   $vars[$idx]
        set -l label $labels[$idx]
        set -l type  $types[$idx]
        set -l hint  $hints[$idx]

        # Badge (7 visible cols) + value field
        set -l badge
        set -l field
        if test $type = bool
            # Booleans store true/false (sponge convention); unset = DEFAULT.
            # The frame is told this page's vocabulary rather than merging
            # true/on: a hand-set "on" here must keep rendering DEFAULT.
            set badge (__config_settings_frame badge (__config_settings_get_raw $var) true false)
            set field "default: $hint"
        else
            set -l raw (__config_settings_get_raw $var)
            if test "$raw" = DEFAULT
                set badge "$c_dim""DEFAULT$c_reset"
                set field "$hint"
            else
                switch $type
                    case path
                        set badge "$c_ok"" PATH  $c_reset"
                    case int
                        set badge "$c_ok""  INT  $c_reset"
                    case list
                        set badge "$c_ok""  LIST $c_reset"
                    case '*'
                        set badge "$c_ok""  STR  $c_reset"
                end
                set field "$raw"
            end
        end

        # Inline edit: render the active row's field as the live buffer with a
        # block caret, tail-anchored so the caret stays visible as text grows.
        if test "$edit_mode" = edit -a $i -eq $cur_row
            set -l fw (math $iw - 33)
            set -l avail (math $fw - 1)
            set -l shown "$edit_buf"
            set -l blen (string length -- "$edit_buf")
            if test $blen -gt $avail
                set shown (string sub -s (math $blen - $avail + 1) -- "$edit_buf")
            end
            set badge "$c_head"" EDIT  $c_reset"
            set field "$shown"(set_color --reverse)" "(set_color normal)
        end

        # `shorten` ellipsises the value: unlike the toggle page's per-tier
        # descriptions, these fields hold arbitrary user values. The edit row
        # is the exception -- its field is already length-constrained above
        # and carries a reverse-video caret whose escapes `string shorten`
        # miscounts, so it pads directly.
        set -l fit shorten
        if test "$edit_mode" = edit -a $i -eq $cur_row
            set fit pad
        end
        __config_settings_frame row $iw $p \
            (__config_settings_frame cursor $i $cur_row) \
            $label 12 $badge $field $fit
    end

    # ── Pad blank rows so chrome(6) + nrows + blanks = 16 ─────────────────
    set -l blanks (math 10 - $nrows)
    for i in (seq 1 $blanks)
        printf '%s│%s│\n' $p (string repeat -n $iw ' ')
    end

    # ── Bottom divider ────────────────────────────────────────────────────
    printf '%s│%s│\n' $p $HBR

    # ── Hint line (changes while editing) ─────────────────────────────────
    set -l hint_line " ↑↓ move  Enter edit  ←/h clear  Tab page  q quit"
    if test "$edit_mode" = edit
        set hint_line " type value   Enter save   Esc cancel   ⌫ delete"
    end
    printf '%s│%s%s%s│\n' $p $c_dim (string pad -r -w $iw -- $hint_line) $c_reset

    # ── Bottom border ─────────────────────────────────────────────────────
    printf '%s└%s┘\n' $p $HBR
end
