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

    set -l c_ok    (set_color green)
    set -l c_err   (set_color red)
    set -l c_dim   (set_color brblack)
    set -l c_sel   (set_color --bold magenta)
    set -l c_head  (set_color --bold cyan)
    set -l c_reset (set_color normal)

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
    set -l iw 50
    if test "$COLUMNS" -ge 90
        set iw 76
    else if test "$COLUMNS" -ge 86
        set iw 72
    else if test "$COLUMNS" -ge 82
        set iw 68
    end
    set -l HBR (string repeat -n $iw '─')
    set -l p (string repeat -n (math --scale=0 "max(0, ($COLUMNS - ($iw + 2)) / 2)") ' ')

    # ── Line 1: top border with title ─────────────────────────────────────
    set -l title_dashes (math $iw - (string length -- $title) - 3)
    printf '%s┌─%s %s %s┐\n' \
        $p $c_head "$title$c_reset" (string repeat -n $title_dashes '─')

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
            set -l val (__config_settings_get_raw $var)
            switch $val
                case true
                    set badge "$c_ok""     ON$c_reset"
                case false
                    set badge "$c_err""OFF    $c_reset"
                case '*'
                    set badge "$c_dim""DEFAULT$c_reset"
            end
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

        set -l curs "  "
        if test $i -eq $cur_row
            set curs "$c_sel▶$c_reset "
        end

        set -l fw (math $iw - 33)
        set -l lpad (string pad -r -w 12 -- $label)
        # The edit field is already length-constrained and contains a reverse
        # caret; running it through `string shorten` miscounts the escapes, so
        # pad it directly. Non-edit fields still shorten to add an ellipsis.
        set -l fpad
        if test "$edit_mode" = edit -a $i -eq $cur_row
            set fpad (string pad -r -w $fw -- "$field")
        else
            set fpad (string pad -r -w $fw -- (string shorten -m $fw -- "$field"))
        end
        printf '%s│  %s%s [ %s ]  %s   │\n' $p $curs $lpad $badge $fpad
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
