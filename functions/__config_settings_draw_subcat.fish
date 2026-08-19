# Copyright (C) 2026 Rootiest
# SPDX-License-Identifier: AGPL-3.0-or-later

# SYNOPSIS
#   __config_settings_draw_subcat <cur_row> <cur_scope> <category_var>
#
# DESCRIPTION
#   Renders the sub-category drill-down page for one C1-C6 category:
#   the category's own toggle at the top (still meaningful as the cascade
#   default for its sub-categories), then one row per sub-category from
#   __config_settings_subcats, sized dynamically instead of the fixed
#   6-row layout __config_settings_draw uses for the category list.
#   Follows the same width-tier and center-padding conventions as
#   __config_settings_draw so the panel doesn't visibly jump between the
#   two pages.
#
#   Label and description fields are defensively truncated to their field
#   width before padding (string pad only ever grows a string, never
#   shrinks it) -- sub-category labels/descriptions are static data from
#   __config_settings_subcats, not authored per width-tier the way
#   __config_settings_draw's own category descriptions are, so a couple of
#   them are longer than the narrower tiers' fields (e.g. "Notifications"
#   is 13 chars against a 12-char label field; several descriptions run
#   well past the 17-char field at the narrowest tier). Truncating keeps
#   the box perfectly rectangular in every case instead of only in the
#   cases the static text happens to fit.
#
# ARGUMENTS
#   cur_row       0-based highlighted row (0 = the category's own toggle;
#                 1..N = sub-category rows)
#   cur_scope     "universal" or "session"
#   category_var  One of the six __fish_config_op_<category> names
#
# EXIT STATUS
#   0  Always
#
# EXAMPLE
#   __config_settings_draw_subcat 1 universal __fish_config_op_aliases
function __config_settings_draw_subcat
    set -l cur_row      $argv[1]
    set -l cur_scope    $argv[2]
    set -l category_var $argv[3]

    set -l c_ok    (set_color green)
    set -l c_err   (set_color red)
    set -l c_dim   (set_color brblack)
    set -l c_sel   (set_color --bold magenta)
    set -l c_head  (set_color --bold cyan)
    set -l c_reset (set_color normal)

    set -l rows (__config_settings_subcats $category_var)
    set -l n (count $rows)

    # ── Width tier: matches __config_settings_draw's 6-col-per-side steps ──
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

    # Label field is 13 wide (one wider than __config_settings_draw's 12) --
    # the longest real sub-category label ("Notifications") is 13 chars.
    # Description field absorbs the difference so every row still totals
    # iw+2, matching the surrounding box lines exactly.
    set -l label_w 13
    set -l desc_w (math $iw - 34)

    set -l cat_label (string replace -r '^__fish_config_op_' '' -- $category_var)
    # Scope indicator: toggling a row on this page writes -U (Universal,
    # persistent) or -g (Session, this-shell-only) -- the title must say
    # which, since it isn't otherwise visible anywhere on the page.
    set -l scope_label Universal
    test "$cur_scope" = session; and set scope_label Session
    # Title layout is "┌─ Sub-categories: <label> (<scope>) ───┐"; the
    # dash count must absorb every visible char added around cat_label so
    # the line still totals iw+2, matching the surrounding box exactly --
    # see the DESCRIPTION doc comment above for why this is hand-verified,
    # not eyeballed.
    set -l title_dashes (math $iw - (string length -- $cat_label) - (string length -- $scope_label) - 22)
    printf '%s┌─%s Sub-categories: %s (%s)%s %s┐\n' \
        $p $c_head "$cat_label" $scope_label "$c_reset" (string repeat -n (math "max(0, $title_dashes)") '─')

    printf '%s│%s│\n' $p $HBR

    # Row 0: the category's own toggle, still meaningful as the cascade
    # default any DEFAULT-valued sub-category below falls back to.
    set -l cat_val (__config_settings_get_val $category_var $cur_scope)
    set -l cat_badge
    switch $cat_val
        case on
            set cat_badge "$c_ok""     ON$c_reset"
        case off
            set cat_badge "$c_err""OFF    $c_reset"
        case '*'
            set cat_badge "$c_dim""DEFAULT$c_reset"
    end
    set -l cat_curs "  "
    if test $cur_row -eq 0
        set cat_curs "$c_sel▶$c_reset "
    end
    set -l cat_desc "cascade default"
    if test $iw -ge 68
        set cat_desc "default for all sub-cats below"
    end
    if test $iw -ge 72
        set cat_desc "default for all sub-categories below"
    end
    printf '%s│  %s%s [ %s ]  %s   │\n' $p $cat_curs \
        (string pad -r -w $label_w -- "(category)") $cat_badge \
        (string pad -r -w $desc_w -- (string sub -l $desc_w -- $cat_desc))

    printf '%s│    %s  │\n' $p (string repeat -n (math $iw - 6) '─')

    for i in (seq 1 $n)
        set -l fields (string split -- \t $rows[$i])
        set -l slug  $fields[1]
        set -l label $fields[2]
        set -l desc  $fields[3]
        set -l subcat_var "$category_var"_(string replace -a -- '-' '_' $slug)

        set -l val (__config_settings_get_val $subcat_var $cur_scope)
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
        if test $i -eq $cur_row
            set curs "$c_sel▶$c_reset "
        end

        set -l lpad (string pad -r -w $label_w -- (string sub -l $label_w -- $label))
        set -l dpad (string pad -r -w $desc_w -- (string sub -l $desc_w -- $desc))
        printf '%s│  %s%s [ %s ]  %s   │\n' $p $curs $lpad $badge $dpad
    end

    printf '%s│%s│\n' $p $HBR
    set -l hint " ↑↓/kj move  ←→/hl set  Esc back  q quit"
    printf '%s│%s%s%s│\n' $p $c_dim (string pad -r -w $iw -- $hint) $c_reset
    printf '%s└%s┘\n' $p $HBR
end
