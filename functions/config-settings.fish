# Copyright (C) 2026 Rootiest
# SPDX-License-Identifier: AGPL-3.0-or-later

# CATEGORY
#   14-miscellaneous
#
# DEPENDENCIES
#   __fish_palette, __config_settings_state, __config_settings_apply,
#   __config_settings_set_value, python3
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
#   the variable so the master switch / built-in default applies. On the
#   Universal/Session pages, Enter on a category row (C1–C6) opens that
#   category's sub-category drill-down page, which leads with the category's
#   own toggle; Escape backs out. Value rows (Sponge, Paths) use Enter to edit
#   inline and ← / h to reset to the row default; committing a blank edit does
#   the same. List rows (e.g. Extra secret, OK codes) accept values separated
#   by commas and/or whitespace — "A, B", "A,B" and "A B" all yield the same
#   two entries. Tab / Shift-Tab cycle through pages.
#
#   `/` filters the current page on label and description. On the Universal and
#   Session pages the filter also reaches into every category's sub-categories,
#   listing hits as "Category › Sub", so a sub-category can be toggled without
#   drilling into its parent first.
#
#   Edits are collected while the TUI runs and applied in one batch when it
#   exits, via __config_settings_apply and __config_settings_set_value. The
#   status bar shows a pending count. This is a deliberate consequence of the
#   renderer being a child process: a child cannot reach into its parent shell
#   to `set -g`, so the Session page's edits come back as a fish script the
#   function sources on exit, and the Universal page rides the same path for
#   consistency. Always available regardless of __fish_config_opinionated state.
#
#   The Sponge and Paths pages always write universal variables — these are
#   persistent, set-and-forget settings with no per-session scope. Editing a
#   scrollback row updates both the __fish_scrollback_history_* source-of-truth
#   variables and the exported SCROLLBACK_HISTORY_* mirrors, so the AUR/tmux/
#   zellij log wrappers (which read the exported names) see the change in the
#   running session. Editing Dots link re-runs __fish_user_dots_link.
#
#   The panel is drawn by scripts/config-settings-tui.py using Python's stdlib
#   `curses`, which owns the cell arithmetic, the alternate screen and the
#   redraw diffing. It resizes with the terminal and needs no width tiers.
#
#   Navigation:
#     ↑ ↓ / k j     Move cursor
#     ← → / h l     Toggle rows: OFF ← DEFAULT → ON
#     ←  / h        Value rows: reset to default
#     Enter         Category rows: open the sub-category page.
#                   Value rows: edit inline
#     /             Filter, sub-categories included
#     Escape        Back out of a sub-category page, or clear the filter
#     Tab / S-Tab   Next / previous page
#     ?             Help overlay
#     q             Apply pending edits and exit
#
# ARGUMENTS
#   -h, --help  Print usage and exit
#
# EXIT STATUS
#   0  Exited normally
#   1  Unknown flag, no TTY, or python3/curses unavailable
#
# EXAMPLE
#   config-settings
function config-settings --description 'Interactive TUI for managing fish config settings'
    __fish_palette

    # ── Argument parsing ──────────────────────────────────
    for arg in $argv
        switch $arg
            case -h --help
                echo "$c_head""Usage:$c_reset $c_cmd""config-settings$c_reset $c_flag""[-h]$c_reset"
                echo
                echo "  Interactive TUI for managing fish config settings."
                echo "  Edits are applied in one batch when the TUI exits."
                echo
                echo "$c_head""Navigation:$c_reset"
                echo "  $c_flag↑ ↓$c_reset or $c_flag""k j$c_reset    Move cursor up / down"
                echo "  $c_flag← →$c_reset or $c_flag""h l$c_reset    Toggle rows: OFF ← DEFAULT → ON"
                echo "  $c_flag""Enter$c_reset         Open sub-category page (Universal / Session);"
                echo "                edit value (Sponge / Paths pages)"
                echo "  $c_flag← / h$c_reset         Reset value to default (value rows)"
                echo "  $c_flag/$c_reset             Filter rows, sub-categories included"
                echo "  $c_flag""Tab / S-Tab$c_reset   Next / previous page"
                echo "  $c_flag""Esc$c_reset           Leave sub-category page / clear filter"
                echo "  $c_flag?$c_reset             Help overlay"
                echo "  $c_flag""q$c_reset             Apply pending edits and exit"
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

    # ── Dependencies ──────────────────────────────────────
    # python3 with the curses module. That is stdlib on Arch, Fedora and a
    # full Debian/Ubuntu python3; python3-minimal alone does not carry
    # _curses, so both are checked rather than assumed from `type -q`.
    if not type -q python3
        echo "$c_err""config-settings requires python3.$c_reset" >&2
        return 1
    end
    if not python3 -c 'import curses' 2>/dev/null
        echo "$c_err""config-settings requires python3 with the curses module.$c_reset" >&2
        echo "  Debian/Ubuntu: install the full $c_cmd""python3$c_reset package." >&2
        return 1
    end
    if not isatty stdout
        echo "$c_err""config-settings needs a terminal.$c_reset" >&2
        return 1
    end

    set -l tui (dirname (status filename))/../scripts/config-settings-tui.py
    if not test -f $tui
        echo "$c_err""config-settings: missing $tui$c_reset" >&2
        return 1
    end

    # ── Run the TUI ───────────────────────────────────────
    # The TUI is a child process, so it can neither read the session's global
    # variables nor write them. State goes in as a dump; the edits come back
    # as a fish script this function sources, which is what lets the Session
    # page's `set -g` land in the caller's shell instead of in a child that is
    # about to exit. `command` throughout: this repo's own aliases shadow rm.
    set -l work (command mktemp -d)
    __config_settings_state >$work/state

    python3 $tui --state $work/state --emit $work/edits
    set -l rc $status

    if test $rc -eq 0 -a -s $work/edits
        source $work/edits
    end

    command rm -rf $work
    return $rc
end
