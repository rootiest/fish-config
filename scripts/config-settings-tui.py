#!/usr/bin/env python3
# Copyright (C) 2026 Rootiest
# SPDX-License-Identifier: AGPL-3.0-or-later
#
# SYNOPSIS
#   config-settings-tui.py [--state <file>] [--emit <file>] [--self-test]
#
# DESCRIPTION
#   Front-end for `config-settings`, rendered with Python's stdlib `curses`.
#   This process never touches fish state directly. It reads a state dump on
#   the way in and writes a fish script of the edits on the way out; the
#   `config-settings` function sources that script, so `set -g` lands in the
#   caller's shell rather than in a child that is about to exit.
#
#     fish  --(__config_settings_state)-->  --state file  -->  this TUI
#     fish  <--(source)-------------------  --emit  file  <--  this TUI
#
#   Every edit is emitted as a call to an existing helper --
#   __config_settings_apply for scope toggles, __config_settings_set_value for
#   the Sponge and Paths rows -- so list splitting, the SCROLLBACK_HISTORY_*
#   export mirror and the shadow-warning suppression all stay in the fish
#   layer that already owns them. Nothing is applied until the TUI exits.
#
#   The sub-category taxonomy is NOT duplicated here: it arrives in the state
#   dump, sourced from __config_settings_subcats. The category, Sponge and
#   Paths row tables do live here, consolidated from the three fish renderers
#   this replaces.
#
# ARGUMENTS
#   --state <file>  State dump to read. Without it, the dump is obtained by
#                   running `fish -c __config_settings_state`.
#   --emit <file>   Write the resulting fish script here. Without it, the
#                   script is printed to stdout after the TUI exits, applying
#                   nothing -- useful for inspecting a session by hand.
#   --self-test     Exercise the pure logic with no terminal and exit non-zero
#                   on failure. Needs no TTY and no fish.
#
# EXIT STATUS
#   0  Clean exit, or --self-test passed
#   1  --self-test failed, or the state dump could not be obtained
#
# EXAMPLE
#   config-settings                                  # the normal entry point
#   ./scripts/config-settings-tui.py                 # standalone, dry run
#   ./scripts/config-settings-tui.py --self-test

import os
import subprocess
import sys
from typing import NamedTuple

# ncurses reads ESCDELAY at init; 25ms makes bare Esc feel instant instead of
# the 1s default. Must be set before curses is imported and initialised.
os.environ.setdefault("ESCDELAY", "25")

import curses  # noqa: E402

RS, US = "\x1e", "\x1f"   # record / unit separators used by the state dump


# ╭──────────────────────────────────────────────────────────────────────────╮
# │ Row model                                                                │
# ╰──────────────────────────────────────────────────────────────────────────╯

class Row(NamedTuple):
    label: str      # display label
    kind: str       # tri | bool | int | list | path
    hint: str       # shown in the value cell while the variable is unset
    desc: str       # one-line description under the label
    var: str        # fish variable name this row edits
    parent: str     # owning category label, "" for a top-level row
    default: str    # what ← / a blank inline edit resets the row to


TRI = ("", "on", "off")            # DEFAULT → ON → OFF
BOOLS = ("", "true", "false")      # Sponge/Paths convention

# Category rows for the Universal and Session pages. Consolidated from
# __config_settings_draw.fish (descriptions) and config-settings.fish
# (variable names), which this file replaces.
CATEGORIES = [
    Row("Aliases", "tri", "", "shadows: ls→eza, cat→bat, cd→z, rm→trash",
        "__fish_config_op_aliases", "", ""),
    Row("Auto-exec", "tri", "", "Fisher bootstrap, themes, py-venv activate",
        "__fish_config_op_autoexec", "", ""),
    Row("Overrides", "tri", "", "vi-mode, bang-bang, PAGER, CDPATH, starship",
        "__fish_config_op_overrides", "", ""),
    Row("Integrations", "tri", "", "Kitty/WezTerm tab/split fns, notifications",
        "__fish_config_op_integrations", "", ""),
    Row("Logging", "tri", "", "scrollback capture & paru/yay AUR wrappers",
        "__fish_config_op_logging", "", ""),
    Row("Greeting", "tri", "", "fish_greeting & first-run welcome banner",
        "__fish_config_op_greeting", "", ""),
    Row("Master", "tri", "", "master off-switch: overrides all categories",
        "__fish_config_opinionated", "", ""),
]

# Value rows. Variables, types and reset targets mirror the sponge_/paths_
# tables that config-settings.fish carried; the reset targets are load-bearing
# (sponge reads sponge_delay and sponge_successful_exit_codes with no fallback,
# so those must never be left unset, while the path rows tolerate being unset).
SPONGE = [
    Row("Delay", "int", "2", "entries kept before a failed command is purged",
        "sponge_delay", "", "2"),
    Row("Purge@exit", "bool", "false", "only purge history on shell exit",
        "sponge_purge_only_on_exit", "", ""),
    Row("Allow prev", "bool", "true", "keep commands that previously succeeded",
        "sponge_allow_previously_successful", "", ""),
    Row("OK codes", "list", "0", "exit codes treated as success",
        "sponge_successful_exit_codes", "", "0"),
    Row("Extra secret", "list", "(none)", "extra patterns scrubbed from history",
        "__fish_sponge_extra_sensitive", "", ""),
]

PATHS = [
    Row("Log dir", "path", "~/.terminal_history", "scrollback capture directory",
        "__fish_scrollback_history_dir", "", ""),
    Row("Log max", "int", "100", "max scrollback files retained",
        "__fish_scrollback_history_max_files", "", ""),
    Row("Dots path", "path", "(default)", "user-dots source directory",
        "__fish_user_dots_path", "", ""),
    Row("Dots link", "bool", "on", "symlink ~/.config/.user-dots/fish",
        "__fish_user_dots_symlink", "", ""),
]

PAGES = ["Universal", "Session", "Sponge", "Paths"]
SCOPES = {"Universal": "universal", "Session": "session",
          "Sponge": "universal", "Paths": "universal"}

# Changing this variable has to re-run the linker, exactly as the fish
# implementation did on every ←/→ over the Dots link row.
DOTS_SYMLINK = "__fish_user_dots_symlink"


def subcat_var(category_var, slug):
    """Sub-category variable name, matching config-settings.fish's derivation."""
    return category_var + "_" + slug.replace("-", "_")


# ╭──────────────────────────────────────────────────────────────────────────╮
# │ State dump                                                               │
# ╰──────────────────────────────────────────────────────────────────────────╯

class State:
    """Parsed __config_settings_state output plus the pending edit set.

    Two record types, RS-separated, fields US-separated:

        var <scope> <name> <value>          a variable that is set
        sub <category_var> <slug> <label> <description>

    Absent means unset, which is what DEFAULT renders as. The separators are
    ASCII control characters, so no value these variables can hold needs
    escaping on the way through.
    """

    def __init__(self, text=""):
        self.vals = {}        # (scope, varname) -> value
        self.subs = {}        # category_var -> [(slug, label, desc), ...]
        for rec in text.split(RS):
            if not rec.strip():
                continue
            f = rec.split(US)
            if f[0] == "var" and len(f) >= 4:
                self.vals[(f[1], f[2])] = f[3]
            elif f[0] == "sub" and len(f) >= 5:
                self.subs.setdefault(f[1], []).append((f[2], f[3], f[4]))
        self.orig = dict(self.vals)

    def get(self, scope, var):
        return self.vals.get((scope, var), "")

    def set(self, scope, var, value):
        if value == "":
            self.vals.pop((scope, var), None)
        else:
            self.vals[(scope, var)] = value

    def changed(self):
        keys = set(self.vals) | set(self.orig)
        return sorted(k for k in keys
                      if self.vals.get(k, "") != self.orig.get(k, ""))


def load_state(path):
    """Read a dump from `path`, or ask fish for one when path is None."""
    if path:
        with open(path, encoding="utf-8") as fh:
            return State(fh.read())
    try:
        out = subprocess.run(["fish", "-c", "__config_settings_state"],
                             capture_output=True, text=True, timeout=30)
    except (OSError, subprocess.SubprocessError) as exc:
        raise SystemExit(f"cannot run fish to read config state: {exc}")
    if out.returncode != 0:
        raise SystemExit("fish -c __config_settings_state failed: "
                         + (out.stderr.strip() or f"exit {out.returncode}"))
    return State(out.stdout)


# ╭──────────────────────────────────────────────────────────────────────────╮
# │ Command emission                                                         │
# ╰──────────────────────────────────────────────────────────────────────────╯

def fq(s):
    """Single-quote a string for fish. Inside '', only \\' and \\\\ escape."""
    return "'" + s.replace("\\", "\\\\").replace("'", "\\'") + "'"


def emit(state, rows_by_var):
    """Render the pending edits as fish commands, one per changed variable."""
    lines = []
    relink = False
    for scope, var in state.changed():
        value = state.get(scope, var)
        row = rows_by_var.get(var)
        if row is not None and row.kind in ("int", "list", "path", "bool"):
            lines.append(f"__config_settings_set_value {var} {row.kind} {fq(value)}")
            relink = relink or var == DOTS_SYMLINK
        else:
            # Toggle rows, including every sub-category row. An empty value
            # means DEFAULT, which erases the variable in that scope.
            lines.append(
                f"__config_settings_apply {var} {scope} {value or 'DEFAULT'}")
    if relink:
        lines.append("__fish_user_dots_link")
    return "\n".join(lines) + ("\n" if lines else "")


# ╭──────────────────────────────────────────────────────────────────────────╮
# │ Pure view helpers                                                        │
# ╰──────────────────────────────────────────────────────────────────────────╯

def matches(row, needle):
    return needle in row.label.lower() or needle in row.desc.lower()


def sub_rows(state, cat):
    """Sub-category rows for one category, from the taxonomy in the dump."""
    return [Row(label, "tri", "", desc, subcat_var(cat.var, slug), cat.label, "")
            for slug, label, desc in state.subs.get(cat.var, [])]


def build_rows(state, page, drill, needle):
    """The rows a page shows, given the drill-down and filter in effect.

    An unfiltered category page lists categories only. Filtering flattens the
    tree: a matching category is listed, and so is any matching sub-category of
    any category, labelled "Category › Sub" so the row still says where it
    lives. That is the only way to reach a sub-category without drilling.
    """
    if page in ("Sponge", "Paths"):
        rows = SPONGE if page == "Sponge" else PATHS
        return [r for r in rows if matches(r, needle)] if needle else list(rows)

    if drill:
        cat = next((c for c in CATEGORIES if c.label == drill), None)
        if cat is None:
            return []
        return [cat] + sub_rows(state, cat)

    if not needle:
        return list(CATEGORIES)

    out = []
    for cat in CATEGORIES:
        if matches(cat, needle):
            out.append(cat)
        for sub in sub_rows(state, cat):
            if matches(sub, needle):
                out.append(sub._replace(label=f"{cat.label} › {sub.label}"))
    return out


def cycle(value, kind, forward):
    """Advance a toggle one step. Non-toggle kinds are edited, not cycled."""
    ring = TRI if kind == "tri" else BOOLS
    i = ring.index(value) if value in ring else 0
    return ring[(i + (1 if forward else -1)) % len(ring)]


def ell(text, room):
    """Truncate with an ellipsis so a clipped description reads as clipped."""
    if room <= 0:
        return ""
    return text if len(text) <= room else text[: room - 1] + "…"


# ╭──────────────────────────────────────────────────────────────────────────╮
# │ Rendering                                                                │
# ╰──────────────────────────────────────────────────────────────────────────╯

SIDEBAR_W = 16
MIN_W, MIN_H = 60, 14

C_FRAME, C_TITLE, C_SEL, C_ON, C_OFF, C_DEF, C_DIM, C_HINT, C_BAR = range(1, 10)


def init_colors():
    curses.start_color()
    try:
        curses.use_default_colors()
        bg = -1
    except curses.error:
        bg = curses.COLOR_BLACK
    for pair, fg in {
        C_FRAME: curses.COLOR_BLUE,
        C_TITLE: curses.COLOR_MAGENTA,
        C_SEL: curses.COLOR_CYAN,
        C_ON: curses.COLOR_GREEN,
        C_OFF: curses.COLOR_RED,
        C_DEF: curses.COLOR_YELLOW,
        C_DIM: curses.COLOR_BLACK,
        C_HINT: curses.COLOR_CYAN,
        C_BAR: curses.COLOR_WHITE,
    }.items():
        curses.init_pair(pair, fg, bg)


def put(win, y, x, text, attr=0, limit=None):
    """Clipped addstr.

    curses cannot addstr() the bottom-right cell -- writing it would advance
    the cursor off the window. Fill that one cell with insstr(), which does
    not move the cursor, so the frame closes instead of losing its corner.
    """
    h, w = win.getmaxyx()
    if y < 0 or y >= h or x >= w:
        return
    room = (w - x) if limit is None else min(limit, w - x)
    if room <= 0:
        return
    text = text[:room]
    if not text:
        return
    try:
        if y == h - 1 and x + len(text) >= w:
            if len(text) > 1:
                win.addstr(y, x, text[:-1], attr)
            win.insstr(y, w - 1, text[-1], attr)
        else:
            win.addstr(y, x, text, attr)
    except curses.error:
        pass


def badge(value, kind, hint):
    """The right-hand value cell and its colour pair."""
    if kind in ("tri", "bool"):
        on = "on" if kind == "tri" else "true"
        off = "off" if kind == "tri" else "false"
        if value == on:
            return "[      ON ]", C_ON
        if value == off:
            return "[ OFF     ]", C_OFF
        return "[ DEFAULT ]", C_DEF
    return (value, C_ON) if value else (hint, C_DIM)


class App:
    def __init__(self, stdscr, state):
        self.scr = stdscr
        self.state = state
        self.page = 0
        self.row = 0
        self.filter = ""
        self.mode = "nav"          # nav | filter | edit | help
        self.buf = ""              # filter / inline-edit scratch buffer
        self.drill = None          # category label while drilled in
        self.msg = ""
        self.row_hits = []         # screen row -> row index, for mouse clicks

    # ── data helpers ──────────────────────────────────────────────────────
    @property
    def page_name(self):
        return PAGES[self.page]

    @property
    def scope(self):
        return SCOPES[self.page_name]

    def visible_rows(self):
        return build_rows(self.state, self.page_name, self.drill,
                          self.filter.lower())

    def current(self):
        rows = self.visible_rows()
        return rows[self.row] if rows else None

    def value_of(self, row):
        return self.state.get(self.scope, row.var)

    # ── drawing ───────────────────────────────────────────────────────────
    def draw(self):
        scr = self.scr
        scr.erase()
        h, w = scr.getmaxyx()
        if h < MIN_H or w < MIN_W:
            put(scr, 0, 0, f"terminal too small ({w}x{h}); need {MIN_W}x{MIN_H}")
            scr.noutrefresh()
            curses.doupdate()
            return

        frame = curses.color_pair(C_FRAME)
        put(scr, 0, 0, "┌" + "─" * (w - 2) + "┐", frame)
        put(scr, 0, 2, " Opinionated Settings ",
            curses.color_pair(C_TITLE) | curses.A_BOLD)
        top, bot = 1, h - 3
        for y in range(top, bot + 1):
            put(scr, y, 0, "│", frame)
            put(scr, y, SIDEBAR_W + 1, "│", frame)
            put(scr, y, w - 1, "│", frame)
        put(scr, h - 2, 0,
            "├" + "─" * SIDEBAR_W + "┴" + "─" * (w - SIDEBAR_W - 3) + "┤", frame)
        put(scr, h - 1, 0, "│", frame)
        put(scr, h - 1, w - 1, "│", frame)

        self.draw_sidebar(top, bot)
        self.draw_detail(top, bot, w)
        self.draw_status(h, w)

        scr.noutrefresh()
        if self.mode == "help":
            self.draw_help(h, w)
        curses.doupdate()

    def draw_sidebar(self, top, bot):
        scr = self.scr
        put(scr, top, 2, "PAGES", curses.color_pair(C_DIM) | curses.A_BOLD)
        for i, name in enumerate(PAGES):
            y = top + 1 + i
            if y > bot:
                break
            sel = i == self.page and self.drill is None
            attr = curses.color_pair(C_SEL) | curses.A_BOLD if sel else 0
            put(scr, y, 2, ("▸ " if sel else "  ") + name, attr, SIDEBAR_W - 2)
        y = top + len(PAGES) + 2
        if y <= bot:
            put(scr, y, 2, "FILTER", curses.color_pair(C_DIM) | curses.A_BOLD)
            if self.mode == "filter":
                shown, attr = "/" + self.buf + "_", curses.color_pair(C_HINT) | curses.A_BOLD
            elif self.filter:
                shown, attr = "/" + self.filter, curses.color_pair(C_HINT)
            else:
                shown, attr = "(none)", curses.color_pair(C_DIM)
            put(scr, y + 1, 2, ell(shown, SIDEBAR_W - 2), attr, SIDEBAR_W - 2)

    def draw_detail(self, top, bot, w):
        scr = self.scr
        left = SIDEBAR_W + 3
        width = w - left - 1
        rows = self.visible_rows()
        self.row_hits = []

        if self.drill is not None:
            put(scr, top, left, ell(f"{self.drill} ▸ sub-categories", width),
                curses.color_pair(C_TITLE) | curses.A_BOLD, width)
            top += 1

        if not rows:
            put(scr, top, left, "no rows match", curses.color_pair(C_DIM), width)
            return

        per = 3                     # value line, description line, separator
        capacity = max(1, (bot - top + 1) // per)
        first = max(0, min(self.row - capacity + 1, len(rows) - capacity))

        for i in range(first, min(len(rows), first + capacity)):
            row = rows[i]
            y = top + (i - first) * per
            sel = i == self.row
            self.row_hits.append((y, i))
            self.row_hits.append((y + 1, i))

            if self.mode == "edit" and sel:
                cell, cattr = ell(self.buf + "_", width - 4), C_HINT
            else:
                cell, cattr = badge(self.value_of(row), row.kind, row.hint)
                cell = ell(cell, width - 4)

            lattr = curses.color_pair(C_SEL) | curses.A_BOLD if sel else curses.A_BOLD
            put(scr, y, left, ("▸ " if sel else "  ") + row.label, lattr,
                max(0, width - len(cell) - 2))
            put(scr, y, left + width - len(cell), cell,
                curses.color_pair(cattr) | (curses.A_BOLD if sel else 0))
            put(scr, y + 1, left + 4, ell(row.desc, width - 4),
                curses.color_pair(C_DIM), width - 4)
            if y + 2 <= bot and i + 1 < min(len(rows), first + capacity):
                put(scr, y + 2, left, "─" * width,
                    curses.color_pair(C_FRAME) | curses.A_DIM)

    def draw_status(self, h, w):
        if self.mode == "edit":
            keys = "⏎ commit   Esc cancel   (blank resets to default)"
        elif self.mode == "filter":
            keys = "⏎ apply   Esc clear"
        elif self.drill is not None:
            keys = "↑↓ move  ←→ set  Esc back  ? help  q apply & quit"
        elif w >= 96:
            keys = "↑↓ move  ←→ set  ⏎ drill/edit  Tab page  / filter  ? help  q apply & quit"
        else:
            keys = "↑↓ ←→ ⏎  Tab pg  / filter  ? help  q quit"
        avail = w - 4
        put(self.scr, h - 1, 2, keys, curses.color_pair(C_BAR) | curses.A_BOLD, avail)

        n = len(self.state.changed())
        note = self.msg or (f"{n} pending" if n else "")
        room = avail - len(keys) - 3
        if note and room > 8:
            attr = C_DEF if not self.msg and n else C_DIM
            put(self.scr, h - 1, 2 + len(keys) + 3, ell(note, room),
                curses.color_pair(attr), room)

    def draw_help(self, h, w):
        lines = [
            "",
            "  Navigation",
            "    ↑ ↓ / k j      move between rows",
            "    Tab / ⇧Tab     next / previous page",
            "    ⏎              drill into sub-categories, or edit a value",
            "    Esc            leave sub-categories / clear filter",
            "",
            "  Values",
            "    ← → / h l      cycle DEFAULT → ON → OFF",
            "    ⏎              inline edit (int, list and path rows)",
            "    blank + ⏎      reset the row to its default",
            "",
            "  Filter",
            "    /              match label and description",
            "    on a category page the filter also reaches sub-categories,",
            "    listed as \"Category › Sub\" -- toggle them without drilling",
            "",
            "  Other",
            "    mouse          click a row to select, click its value to cycle",
            "    ?              toggle this overlay",
            "    q              apply pending edits and quit",
            "",
            "  Edits are written when the TUI exits, not as you make them.",
            "",
        ]
        bw = min(w - 4, max(len(x) for x in lines) + 4)
        bh = min(h - 2, len(lines) + 2)
        win = curses.newwin(bh, bw, (h - bh) // 2, (w - bw) // 2)
        win.bkgd(" ", curses.color_pair(C_BAR))
        win.attrset(curses.color_pair(C_FRAME))
        win.box()
        put(win, 0, 3, " Help ", curses.color_pair(C_TITLE) | curses.A_BOLD)
        for i, line in enumerate(lines[: bh - 2], start=1):
            attr = curses.A_BOLD if line.strip() and not line.startswith("    ") else 0
            put(win, i, 1, line, attr, bw - 2)
        win.noutrefresh()

    # ── input ─────────────────────────────────────────────────────────────
    def clamp(self):
        n = len(self.visible_rows())
        self.row = 0 if n == 0 else max(0, min(self.row, n - 1))

    def handle(self, ch):
        """Return False to quit."""
        if ch == curses.KEY_RESIZE:
            return True
        if self.mode == "help":
            self.mode = "nav"
            return True
        if self.mode in ("filter", "edit"):
            return self.handle_text(ch)
        return self.handle_nav(ch)

    def handle_text(self, ch):
        if ch in (curses.KEY_ENTER, 10, 13):
            if self.mode == "filter":
                self.filter = self.buf
            else:
                self.commit_edit()
            self.mode, self.buf = "nav", ""
            self.clamp()
        elif ch == 27:  # Esc
            if self.mode == "filter":
                self.filter = ""
            self.mode, self.buf = "nav", ""
            self.clamp()
        elif ch in (curses.KEY_BACKSPACE, 127, 8):
            self.buf = self.buf[:-1]
            if self.mode == "filter":
                self.filter = self.buf
                self.clamp()
        elif 32 <= ch < 127:
            self.buf += chr(ch)
            if self.mode == "filter":
                self.filter = self.buf
                self.clamp()
        return True

    def handle_nav(self, ch):
        rows = self.visible_rows()
        key = chr(ch) if 32 <= ch < 127 else ""
        self.msg = ""

        if key == "q":
            return False
        if key == "?":
            self.mode = "help"
        elif ch == curses.KEY_DOWN or key == "j":
            self.row = (self.row + 1) % max(1, len(rows))
        elif ch == curses.KEY_UP or key == "k":
            self.row = (self.row - 1) % max(1, len(rows))
        elif ch == curses.KEY_RIGHT or key == "l":
            self.bump(True)
        elif ch == curses.KEY_LEFT or key == "h":
            self.bump(False)
        elif ch == 9 and self.drill is None:            # Tab
            self.page, self.row = (self.page + 1) % len(PAGES), 0
        elif ch == curses.KEY_BTAB and self.drill is None:
            self.page, self.row = (self.page - 1) % len(PAGES), 0
        elif key == "/" and self.drill is None:
            self.mode, self.buf = "filter", self.filter
        elif ch in (curses.KEY_ENTER, 10, 13):
            self.enter()
        elif ch == 27:
            if self.drill is not None:
                self.drill, self.row = None, 0
            elif self.filter:
                self.filter, self.row = "", 0
        elif ch == curses.KEY_MOUSE:
            self.mouse()
        self.clamp()
        return True

    def enter(self):
        row = self.current()
        if not row:
            return
        # A category row drills in, but only from the unfiltered category list.
        # A filtered hit is already the row it names, sub-categories included,
        # so Enter there would be a surprise navigation.
        drillable = (row.kind == "tri" and self.drill is None and not self.filter
                     and self.state.subs.get(row.var))
        if drillable:
            self.drill, self.row = row.label, 0
        elif row.kind in ("int", "list", "path"):
            self.mode, self.buf = "edit", self.value_of(row)
        else:
            self.bump(True)

    def commit_edit(self):
        row = self.current()
        if not row:
            return
        value = self.buf.strip() or row.default
        self.state.set(self.scope, row.var, value)
        self.msg = f"{row.label} = {value or 'default'}"

    def bump(self, forward):
        row = self.current()
        if not row:
            return
        if row.kind in ("tri", "bool"):
            new = cycle(self.value_of(row), row.kind, forward)
            self.state.set(self.scope, row.var, new)
            self.msg = f"{row.label} = {new or 'DEFAULT'}"
        elif not forward:
            self.state.set(self.scope, row.var, row.default)
            self.msg = f"{row.label} reset to default"

    def mouse(self):
        try:
            mouse = curses.getmouse()
        except curses.error:
            return
        mx, my = mouse[1], mouse[2]
        for y, idx in self.row_hits:
            if y == my:
                if idx == self.row and mx > self.scr.getmaxyx()[1] - 16:
                    self.bump(True)
                else:
                    self.row = idx
                return

    def run(self):
        curses.curs_set(0)
        self.scr.keypad(True)
        curses.mousemask(curses.BUTTON1_CLICKED)
        while True:
            self.draw()
            try:
                ch = self.scr.getch()
            except KeyboardInterrupt:
                return          # Ctrl-C keeps the edits made so far, like q
            if not self.handle(ch):
                return


# ╭──────────────────────────────────────────────────────────────────────────╮
# │ Entry points                                                             │
# ╰──────────────────────────────────────────────────────────────────────────╯

def rows_by_var():
    """Every value row, keyed by variable, for emit()'s type lookup."""
    return {r.var: r for r in SPONGE + PATHS}


def self_test():
    """Exercise the pure logic. No terminal, no fish."""
    dump = RS.join([
        US.join(["var", "universal", "__fish_config_op_aliases", "on"]),
        US.join(["var", "session", "__fish_config_op_aliases", "off"]),
        US.join(["var", "universal", "sponge_delay", "5"]),
        US.join(["sub", "__fish_config_op_aliases", "filesystem",
                 "Filesystem", "ls, cat, cd, du, mkdir, rm, mv, zoxide"]),
        US.join(["sub", "__fish_config_op_aliases", "shell-tools",
                 "Shell-tools", "bash, less, help"]),
        US.join(["sub", "__fish_config_op_logging", "pkg-logs",
                 "Pkg-logs", "paru/yay AUR log wrappers"]),
    ])
    st = State(dump)

    # -- dump parsing ---------------------------------------------------
    assert st.get("universal", "__fish_config_op_aliases") == "on"
    assert st.get("session", "__fish_config_op_aliases") == "off"
    assert st.get("universal", "__fish_config_op_greeting") == ""
    assert len(st.subs["__fish_config_op_aliases"]) == 2
    assert st.changed() == []

    # -- variable naming matches config-settings.fish --------------------
    assert subcat_var("__fish_config_op_aliases", "shell-tools") \
        == "__fish_config_op_aliases_shell_tools"

    # -- toggle cycling --------------------------------------------------
    assert cycle("", "tri", True) == "on"
    assert cycle("on", "tri", True) == "off"
    assert cycle("off", "tri", True) == ""
    assert cycle("", "tri", False) == "off"
    assert cycle("", "bool", True) == "true"

    # -- unfiltered pages ------------------------------------------------
    assert build_rows(st, "Universal", None, "") == CATEGORIES
    assert build_rows(st, "Sponge", None, "") == SPONGE

    # -- drill-down leads with the category's own toggle ------------------
    drilled = build_rows(st, "Universal", "Aliases", "")
    assert [r.label for r in drilled] == ["Aliases", "Filesystem", "Shell-tools"]
    assert drilled[1].var == "__fish_config_op_aliases_filesystem"
    assert build_rows(st, "Universal", "Nonexistent", "") == []

    # -- the filter reaches sub-categories -------------------------------
    hits = build_rows(st, "Universal", None, "log")
    assert [r.label for r in hits] == ["Logging", "Logging › Pkg-logs"], hits
    assert hits[1].var == "__fish_config_op_logging_pkg_logs"
    # A sub-category match with no matching parent still surfaces.
    hits = build_rows(st, "Universal", None, "zoxide")
    assert [r.label for r in hits] == ["Aliases › Filesystem"], hits
    # Matching on description, not just label.
    assert [r.label for r in build_rows(st, "Universal", None, "starship")] \
        == ["Overrides"]
    assert build_rows(st, "Universal", None, "zzz") == []
    assert [r.label for r in build_rows(st, "Sponge", None, "exit")] \
        == ["Purge@exit", "OK codes"]

    # -- fish quoting ----------------------------------------------------
    assert fq("plain") == "'plain'"
    assert fq("it's") == "'it\\'s'"
    assert fq("a\\b") == "'a\\\\b'"

    # -- emission --------------------------------------------------------
    by_var = rows_by_var()
    st.set("universal", "__fish_config_op_aliases", "off")
    st.set("session", "__fish_config_op_aliases", "")          # -> DEFAULT
    st.set("universal", "__fish_config_op_logging_pkg_logs", "on")
    st.set("universal", "sponge_delay", "9")
    st.set("universal", "__fish_sponge_extra_sensitive", "TOKEN, KEY")
    out = emit(st, by_var).splitlines()
    assert "__config_settings_apply __fish_config_op_aliases universal off" in out
    assert "__config_settings_apply __fish_config_op_aliases session DEFAULT" in out
    assert ("__config_settings_apply __fish_config_op_logging_pkg_logs "
            "universal on") in out
    assert "__config_settings_set_value sponge_delay int '9'" in out
    assert ("__config_settings_set_value __fish_sponge_extra_sensitive list "
            "'TOKEN, KEY'") in out
    assert "__fish_user_dots_link" not in out
    assert len(out) == 5, out

    # -- the dots symlink re-runs the linker, and only then ---------------
    st2 = State(dump)
    st2.set("universal", DOTS_SYMLINK, "false")
    out2 = emit(st2, by_var).splitlines()
    assert out2 == [f"__config_settings_set_value {DOTS_SYMLINK} bool 'false'",
                    "__fish_user_dots_link"], out2

    # -- nothing changed emits nothing -----------------------------------
    assert emit(State(dump), by_var) == ""

    # -- badges and clipping ---------------------------------------------
    assert badge("on", "tri", "")[1] == C_ON
    assert badge("true", "bool", "")[1] == C_ON
    assert badge("false", "bool", "")[1] == C_OFF
    assert badge("", "bool", "x")[1] == C_DEF
    assert badge("", "path", "~/x")[0] == "~/x"
    assert badge("/tmp", "path", "~/x")[0] == "/tmp"
    assert ell("abcdef", 10) == "abcdef"
    assert ell("abcdef", 4) == "abc…"
    assert ell("abcdef", 0) == ""

    print("self-test OK")
    return 0


def main(argv):
    if "--self-test" in argv:
        return self_test()
    if "-h" in argv or "--help" in argv:
        print("usage: config-settings-tui.py [--state <file>] [--emit <file>] "
              "[--self-test]\n\nNormally launched by the `config-settings` "
              "fish function.")
        return 0

    def opt(name):
        return argv[argv.index(name) + 1] if name in argv else None

    state = load_state(opt("--state"))

    def boot(stdscr):
        init_colors()
        App(stdscr, state).run()

    curses.wrapper(boot)

    script = emit(state, rows_by_var())
    out = opt("--emit")
    if out:
        with open(out, "w", encoding="utf-8") as fh:
            fh.write(script)
    elif script:
        sys.stdout.write(script)
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
