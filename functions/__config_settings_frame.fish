# Copyright (C) 2026 Rootiest
# SPDX-License-Identifier: AGPL-3.0-or-later

# SYNOPSIS
#   __config_settings_frame width
#   __config_settings_frame title  <iw> <p> <segment>
#   __config_settings_frame badge  <value> [<on_word> <off_word>]
#   __config_settings_frame cursor <row> <cur_row>
#   __config_settings_frame row    <iw> <p> <curs> <label> <label_w> <badge> <field> <fit>
#
# DESCRIPTION
#   The pieces of the config-settings panel that every page draws identically:
#   the width tier, the title border, the ON/OFF/DEFAULT badge, the cursor cell
#   and one table row. __config_settings_draw, __config_settings_draw_subcat
#   and __config_settings_draw_value each keep their own sequence of lines and
#   their own per-tier text; only these shared computations live here.
#
#   Deliberately owns no page height. Every verb prints exactly one line or one
#   fragment, so how tall a page is remains a property of its caller's line
#   sequence: __config_settings_draw and __config_settings_draw_value are a
#   fixed 16 lines, __config_settings_draw_subcat is 7 + <sub-category count>,
#   and config-settings.fish's wrap-aware erase (\e[<N>A\e[J, sized from
#   panel_h) depends on that difference surviving exactly as it is.
#
#   Row geometry. A row is
#     │ + 2 spaces + cursor(2) + label(label_w) + " [ " + badge(7) + " ]  "
#       + field(field_w) + 3 spaces + │
#   which totals 23 + label_w + field_w and must equal iw + 2. So
#     field_w = iw - 21 - label_w
#   and that single sum reproduces both hand-maintained constants: label_w 12
#   gives iw-33 (the toggle and value pages), label_w 13 gives iw-34 (the
#   sub-category page, whose description field absorbs its wider label).
#
#   Title geometry. "┌─" + segment + dashes + "┐" totals iw + 2, so
#     dashes = iw - visible(segment) - 1
#   The segment arrives already coloured because the three pages place their
#   set_color reset at different byte offsets around the same visible text
#   (__config_settings_draw resets after the trailing space, the other two
#   before it). That difference is invisible on screen and visible to cmp, so
#   each page keeps its own bytes while sharing the arithmetic; --visible
#   discounts the escapes.
#
# ARGUMENTS
#   width   No arguments. Prints the inner width for the current $COLUMNS:
#           >= 90 -> 76, >= 86 -> 72, >= 82 -> 68, otherwise 50.
#   title   iw, the centering prefix, and the pre-coloured title segment.
#   badge   The stored value, then optionally the words this page uses for true
#           and false (default on/off; the value pages store true/false).
#           Anything else renders DEFAULT.
#   cursor  This row's index and the highlighted row's index.
#   row     iw, centering prefix, cursor cell, label, label field width,
#           rendered badge, field text, and the fit policy:
#             pad      pad label and field, never shrink either
#             cut      truncate both to their field width, then pad
#             shorten  pad the label, ellipsise the field with string shorten
#
# EXIT STATUS
#   0  Verb recognised
#   1  Unknown verb
#
# RETURNS
#   The requested panel line or fragment, printed to stdout
#
# NOTES
#   `string pad` only ever grows a string, never shrinks it. That is the whole
#   reason `cut` and `shorten` exist: a caller whose text can exceed its field
#   must shrink it first, or the box stops being rectangular.
#
#   `pad` is not "the default when you don't care". __config_settings_draw's
#   descriptions are authored per width tier to fit their field exactly -- at
#   every tier the longest is precisely the field width -- so applying `cut`
#   there would be a byte-for-byte no-op that silently discards that property
#   and passes the render golden. Which policy a page uses is a real decision,
#   named at each call site. See tests/config-settings-render.fish.
#
# EXAMPLE
#   set -l iw (__config_settings_frame width)
#   __config_settings_frame row $iw $p (__config_settings_frame cursor 0 0) \
#       Aliases 12 (__config_settings_frame badge on) "cmd shadows" pad
function __config_settings_frame
    switch $argv[1]
        # ── Width tier: 6-col buffer per side before stepping up ──────────
        case width
            if test "$COLUMNS" -ge 90
                echo 76
            else if test "$COLUMNS" -ge 86
                echo 72
            else if test "$COLUMNS" -ge 82
                echo 68
            else
                echo 50
            end

            # ── Title border: ┌─<segment><dashes>┐ ────────────────────────────
        case title
            set -l iw $argv[2]
            set -l vis (string length --visible -- "$argv[4]")
            set -l dashes (math "max(0, $iw - $vis - 1)")
            printf '%s┌─%s%s┐\n' $argv[3] "$argv[4]" (string repeat -n $dashes '─')

            # ── Badge: 7 visible columns, coloured ────────────────────────────
            # The truthy/falsy words are arguments rather than one merged
            # vocabulary: merging would make a hand-set "on" in a true/false
            # variable render as ON where it renders DEFAULT today.
        case badge
            set -l on_word on
            set -l off_word off
            if test (count $argv) -ge 4
                set on_word $argv[3]
                set off_word $argv[4]
            end
            switch "$argv[2]"
                case $on_word
                    printf '%s     ON%s' (set_color green) (set_color normal)
                case $off_word
                    printf '%sOFF    %s' (set_color red) (set_color normal)
                case '*'
                    printf '%sDEFAULT%s' (set_color brblack) (set_color normal)
            end

            # ── Cursor cell: 2 visible columns ────────────────────────────────
        case cursor
            if test $argv[2] -eq $argv[3]
                printf '%s▶%s ' (set_color --bold magenta) (set_color normal)
            else
                printf '  '
            end

            # ── One table row ─────────────────────────────────────────────────
        case row
            set -l iw $argv[2]
            set -l p $argv[3]
            set -l curs $argv[4]
            set -l label "$argv[5]"
            set -l label_w $argv[6]
            set -l badge $argv[7]
            set -l field "$argv[8]"
            set -l fit $argv[9]
            set -l field_w (math $iw - 21 - $label_w)
            switch $fit
                case cut
                    set label (string sub -l $label_w -- "$label")
                    set field (string sub -l $field_w -- "$field")
                case shorten
                    set field (string shorten -m $field_w -- "$field")
            end
            printf '%s│  %s%s [ %s ]  %s   │\n' $p $curs \
                (string pad -r -w $label_w -- "$label") $badge \
                (string pad -r -w $field_w -- "$field")

        case '*'
            echo "__config_settings_frame: unknown verb '$argv[1]'" >&2
            return 1
    end
end
