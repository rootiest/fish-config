#!/usr/bin/env fish
# Copyright (C) 2026 Rootiest
# SPDX-License-Identifier: AGPL-3.0-or-later
#
# Golden-output harness for the config-settings TUI renderer.
#
#   fish tests/config-settings-render.fish             compare against the golden
#   fish tests/config-settings-render.fish --update    rewrite the golden
#
# __config_settings_draw, __config_settings_draw_subcat and
# __config_settings_draw_value are hand-tuned layout code: field widths, dash
# counts and pad targets are arithmetic on the width tier, verified by eye once
# and never since. Any refactor of them has to be byte-identical, so this
# renders every page at every width tier, in both scopes, with the cursor on
# every row, and byte-compares the result against a committed baseline.
#
# The golden holds RAW output: the set_color escapes and box drawing exactly as
# the draw functions emit them, plus the \e[<N>A\e[J erase config-settings.fish
# would emit for that panel. Nothing is normalized, folded or pretty-printed --
# the gate is cmp(1) over the bytes, and a one-space change anywhere fails it.
# `diff` is only used to *display* a failure, through cat -v.
#
# Everything runs inside a throwaway HOME/XDG_CONFIG_HOME sandbox. The fixtures
# have to be real universal variables (the Universal page reads universal scope
# through `set --show`), and this repo doubles as a live ~/.config/fish whose
# fish_variables must never be touched by a test run. `fish --no-config` is not
# an option here: under -N, `set -U` silently degrades to global scope, which
# would render the Universal page as all-DEFAULT and prove nothing.
#
# Every external utility below is called through `command`. The outer pass runs
# under the user's real config, which shadows rm (-> trash), cat (-> bat) and
# mkdir, and aliases cp to `cp -i` -- a bare `cp` over an existing golden would
# sit waiting for a confirmation that never comes.

set -l self (command realpath (status filename))
set -l repo (command realpath (command dirname $self)/..)
set -l golden $repo/tests/golden/config-settings-render.txt

# ╭──────────────────────────────────────────────────────────────────────────╮
# │ Outer pass: sandbox, run the render, compare or update                   │
# ╰──────────────────────────────────────────────────────────────────────────╯
if not set -q CS_RENDER_OUT
    set -l sandbox (command mktemp -d)
    command mkdir -p $sandbox/home $sandbox/xdg/fish
    set -l out (command mktemp)
    set -l errf (command mktemp)

    # TERM is pinned so set_color emits a fixed sequence set regardless of the
    # terminal this runs from; COLUMNS is set per case inside the render pass.
    command env -i \
        HOME=$sandbox/home \
        XDG_CONFIG_HOME=$sandbox/xdg \
        PATH="$PATH" \
        TERM=xterm-256color \
        CS_RENDER_OUT=$out \
        fish $self >/dev/null 2>$errf
    set -l render_status $status
    command rm -rf $sandbox

    if test $render_status -ne 0
        echo "  FAIL  render pass exited $render_status"
        command cat $errf >&2
        command rm -f $out $errf
        exit 1
    end

    set -l cases (command grep -c '^### ' $out)
    if contains -- --update $argv
        command mkdir -p (command dirname $golden)
        command cp $out $golden
        echo "golden updated: $cases cases, "(command wc -l <$golden | string trim)" lines, "(command wc -c <$golden | string trim)" bytes"
        command rm -f $out $errf
        exit 0
    end

    if not test -f $golden
        echo "  FAIL  no golden at $golden -- run with --update to create it"
        command rm -f $out $errf
        exit 1
    end

    if command cmp -s $out $golden
        echo "$cases/$cases config-settings render cases byte-identical"
        command rm -f $out $errf
        exit 0
    end

    echo "  FAIL  rendering differs from $golden"
    # cat -v only to make the escapes readable in the report; the gate above is
    # a raw byte compare, never this.
    command diff (command cat -v $golden | psub) (command cat -v $out | psub) | command head -40
    command rm -f $out $errf
    exit 1
end

# ╭──────────────────────────────────────────────────────────────────────────╮
# │ Render pass (inside the sandbox)                                         │
# ╰──────────────────────────────────────────────────────────────────────────╯
# Sourced, not autoloaded: XDG_CONFIG_HOME points at the empty sandbox. Only
# the draw path is ever called -- __config_settings_apply and
# __config_settings_set_value are defined here and never invoked.
for f in $repo/functions/__config_settings_*.fish
    source $f
end

set -l toggle_vars \
    __fish_config_op_aliases \
    __fish_config_op_autoexec \
    __fish_config_op_overrides \
    __fish_config_op_integrations \
    __fish_config_op_logging \
    __fish_config_op_greeting \
    __fish_config_opinionated

set -l categories $toggle_vars[1..6]

# ── Fixtures ──────────────────────────────────────────────────────────────
# Chosen so every badge branch is live somewhere in the golden: an explicit
# truthy (ON), an explicit falsy (OFF), and an unset variable (DEFAULT). The
# session values deliberately differ from the universal ones so the two pages
# cannot render identically by accident.
set -U __fish_config_op_aliases on
set -U __fish_config_op_autoexec off
set -U __fish_config_op_integrations on
set -U __fish_config_op_logging off
set -U __fish_config_opinionated off
# __fish_config_op_overrides, __fish_config_op_greeting: unset -> DEFAULT

set -g __fish_config_op_aliases off
set -g __fish_config_op_overrides on
set -g __fish_config_op_greeting off

# Sub-category fixtures. "Notifications" is the 13-char label the subcat page's
# label field was widened for; multiplexer-capture exercises the slug's '-'->'_'
# rewrite into a variable name.
set -U __fish_config_op_aliases_filesystem on
set -U __fish_config_op_aliases_search off
set -U __fish_config_op_integrations_notifications on
set -U __fish_config_op_logging_multiplexer_capture off
set -g __fish_config_op_aliases_search on

# Value-page fixtures: one per type badge (INT / LIST / PATH) plus unset rows
# for DEFAULT, plus a value long enough to force `string shorten`'s ellipsis at
# every tier.
set -U sponge_delay 5
set -U sponge_purge_only_on_exit true
set -U sponge_allow_previously_successful false
set -U __fish_sponge_extra_sensitive KOPIA_PASSWORD MY_CORP_AUTH
# sponge_successful_exit_codes: unset -> DEFAULT
set -U __fish_scrollback_history_dir /home/tester/very/long/scrollback/history/directory
set -U __fish_user_dots_path /home/tester/.config/.user-dots/fish
set -U __fish_user_dots_symlink false
# __fish_scrollback_history_max_files: unset -> DEFAULT

# ── Case emitter ──────────────────────────────────────────────────────────
# panel_h is passed in by the caller, mirroring __cs_dispatch_draw in
# config-settings.fish: the category list and both value pages are a fixed 16
# lines, a sub-category page is 7 + <sub-category count>. The golden records
# the declared height, the measured line count, and the erase sequence derived
# from the declared height -- so flattening the fixed/dynamic divergence, or
# changing a page's height at all, breaks the compare three ways.
function _cs_render_case --argument-names label panel_h
    set -l cmd $argv[3..]
    set -l t (command mktemp)
    $cmd >$t
    set -l lines (command wc -l <$t | string trim)

    # Wrap-aware erase, byte-for-byte what config-settings.fish emits for a
    # panel of this height at this width in the steady state (last_cols ==
    # COLUMNS). 78 is the widest box (IW=76 + 2 borders).
    set -l pml (math --scale=0 "($COLUMNS + 78) / 2")
    set -l eh (math --scale=0 "$panel_h * max(1, ceil($pml / $COLUMNS))")

    printf '### %s COLUMNS=%d PANEL_H=%d LINES=%d ERASE=' $label $COLUMNS $panel_h $lines
    printf '\e[%dA\e[J' $eh
    printf '\n'
    command cat $t
    command rm -f $t
end

# ── Frame-verb fragments ──────────────────────────────────────────────────
# The shared computations pinned directly, not only through the pages that use
# them. <END> marks the end of each fragment so trailing padding -- which is
# the entire point of a 7-column badge or a 2-column cursor cell -- shows up in
# a diff instead of being invisible whitespace.
function _cs_frame_case --argument-names label
    printf '### frame %s\n' $label
    $argv[2..]
    printf '<END>\n'
end

# ── Cases ─────────────────────────────────────────────────────────────────
# 100 -> IW 76, 88 -> IW 72, 84 -> IW 68, 70 -> IW 50: one COLUMNS value per
# width tier, each a few columns above its threshold.
begin
    for cols in 100 88 84 70
        set -g COLUMNS $cols

        for scope in universal session
            for row in (seq 0 6)
                _cs_render_case "toggle scope=$scope row=$row" 16 \
                    __config_settings_draw $row $scope $toggle_vars
            end
        end

        for category in $categories
            set -l n (count (__config_settings_subcats $category))
            for scope in universal session
                for row in (seq 0 $n)
                    _cs_render_case "subcat cat=$category scope=$scope row=$row" (math 7 + $n) \
                        __config_settings_draw_subcat $row $scope $category
                end
            end
        end

        for row in (seq 0 4)
            _cs_render_case "value page=sponge row=$row" 16 \
                __config_settings_draw_value $row sponge
        end
        for row in (seq 0 3)
            _cs_render_case "value page=paths row=$row" 16 \
                __config_settings_draw_value $row paths
        end

        # Inline editor: only reachable on non-bool rows. Short buffer, a
        # buffer long enough to tail-anchor against the caret, and an empty one.
        _cs_render_case "edit page=sponge row=0 buf=short" 16 \
            __config_settings_draw_value 0 sponge edit 12
        _cs_render_case "edit page=sponge row=4 buf=long" 16 \
            __config_settings_draw_value 4 sponge edit "KOPIA_PASSWORD MY_CORP_AUTH ANOTHER_SECRET_NAME"
        _cs_render_case "edit page=paths row=0 buf=long" 16 \
            __config_settings_draw_value 0 paths edit /home/tester/very/long/scrollback/history/directory
        _cs_render_case "edit page=paths row=2 buf=empty" 16 \
            __config_settings_draw_value 2 paths edit ""
    end

    # Emitted last on purpose: everything above is page output, so the page
    # section's byte offsets never move when this section grows.
    for cols in 100 88 84 70
        set -g COLUMNS $cols
        _cs_frame_case "width cols=$cols" __config_settings_frame width
    end
    set -g COLUMNS 100

    set -l head (set_color --bold cyan)
    set -l rst (set_color normal)
    set -l p_test (string repeat -n 11 ' ')

    for v in on off DEFAULT ''
        _cs_frame_case "badge onoff val=$v" __config_settings_frame badge $v
    end
    for v in true false DEFAULT
        _cs_frame_case "badge boolean val=$v" __config_settings_frame badge $v true false
    end

    _cs_frame_case "cursor hit" __config_settings_frame cursor 3 3
    _cs_frame_case "cursor miss" __config_settings_frame cursor 3 4

    _cs_frame_case "title toggle-page" __config_settings_frame title 76 $p_test \
        "$head Opinionated Settings $rst"
    _cs_frame_case "title subcat-page" __config_settings_frame title 76 $p_test \
        "$head Sub-categories: aliases (Universal)$rst "
    _cs_frame_case "title value-page" __config_settings_frame title 76 $p_test \
        "$head Sponge Settings$rst "

    set -l badge_on (__config_settings_frame badge on)
    _cs_frame_case "row pad lw=12" __config_settings_frame row 76 $p_test \
        (__config_settings_frame cursor 0 0) Aliases 12 $badge_on "cmd shadows" pad
    _cs_frame_case "row cut lw=13" __config_settings_frame row 76 $p_test \
        (__config_settings_frame cursor 0 1) Notifications 13 $badge_on "done, WakaTime hook" cut
    _cs_frame_case "row cut lw=13 overlong" __config_settings_frame row 50 $p_test \
        (__config_settings_frame cursor 0 0) Notifications 13 $badge_on \
        "ls, cat, cd, du, mkdir, rm, mv, zoxide" cut
    _cs_frame_case "row shorten lw=12" __config_settings_frame row 76 $p_test \
        (__config_settings_frame cursor 0 0) "Log dir" 12 $badge_on \
        /home/tester/very/long/scrollback/history/directory shorten
    _cs_frame_case "row shorten lw=12 empty" __config_settings_frame row 50 $p_test \
        (__config_settings_frame cursor 1 0) "Log max" 12 $badge_on "" shorten
end >$CS_RENDER_OUT
