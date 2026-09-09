#!/usr/bin/env python3
# Copyright (C) 2026 Rootiest
# SPDX-License-Identifier: AGPL-3.0-or-later
#
# SYNOPSIS
#   config-settings-tui.py [--self-test]
#
# DESCRIPTION
#   PROTOTYPE front-end for `config-settings`, rendered with Python's stdlib
#   `curses` instead of hand-rolled ANSI cursor arithmetic. The backend is
#   stubbed: values live in an in-memory dict and nothing is read from or
#   written to fish universal/global variables. The point is to evaluate the
#   interaction model and the render engine, not to be functional.
#
#   What curses buys over the fish implementation:
#     - No flicker, structurally. curses diffs its virtual screen against the
#       physical one and emits only the changed cells. The fish version
#       reimplements this by hand in __config_settings_diff_redraw.fish.
#     - Alternate screen + absolute addressing. Stray output cannot desync the
#       display, so the whole class of bugs behind commits 608b022, 4210f3b,
#       93fc5e0 and 3c4f720 cannot occur.
#     - Resize is a repaint, not wrap-factor arithmetic.
#     - Overlays, panes, live filtering and mouse input are a few lines each.
#
# DEPENDENCIES
#   python3 (stdlib only; the `curses` module ships with CPython on Linux --
#   Debian/Ubuntu users who installed python3-minimal alone may need the full
#   `python3` package, which pulls in _curses).
#
# ARGUMENTS
#   --self-test  Exercise the pure state/filter logic without a terminal and
#                exit non-zero on failure. Used by tests; needs no TTY.
#
# EXIT STATUS
#   0  Clean exit, or --self-test passed
#   1  --self-test failed
#
# EXAMPLE
#   ./scripts/config-settings-tui.py
#   ./scripts/config-settings-tui.py --self-test

import os
import sys

# ncurses reads ESCDELAY at init; 25ms makes bare Esc feel instant instead of
# the 1s default. Must be set before curses is initialised.
os.environ.setdefault("ESCDELAY", "25")

import curses  # noqa: E402

# ╭──────────────────────────────────────────────────────────────────────────╮
# │ Stub model                                                               │
# ╰──────────────────────────────────────────────────────────────────────────╯

TRI = ("DEFAULT", "ON", "OFF")

# label, description, [(sub-label, sub-description), ...]
CATEGORIES = [
    ("Aliases", "shadows: ls→eza, cat→bat, cd→z, rm→trash", [
        ("Filesystem", "ls, cat, cd, du, mkdir, rm, mv, zoxide"),
        ("Search", "rg"),
        ("Network", "ping, ssh, yt-dlp"),
        ("Monitor", "top"),
        ("Shell-tools", "bash, less, help"),
        ("Dev-tools", "claude, edit, agy"),
    ]),
    ("Auto-exec", "Fisher bootstrap, themes, py-venv activate", [
        ("Plugins", "Fisher bootstrap"),
        ("Pkg-wrappers", "paru/yay wrapper generation"),
        ("Venv", "Python auto-activation"),
        ("Telemetry", "WakaTime hook bootstrap"),
        ("Sync", "auto-pull, user-dots symlink"),
    ]),
    ("Overrides", "vi-mode, bang-bang, PAGER, CDPATH, starship", [
        ("Key-bindings", "vi-mode, autopair, puffer, bang-bang"),
        ("Environment", "PATH, PAGER, EDITOR, CDPATH"),
        ("Prompt", "Starship, right prompt, theme + FZF colors"),
        ("Privacy", "DO_NOT_TRACK, DISABLE_TELEMETRY"),
    ]),
    ("Integrations", "Kitty/WezTerm tab/split fns, notifications", [
        ("Term-abbrs", "Kitty/WezTerm abbreviations"),
        ("Window-mgmt", "spwin, tab, split"),
        ("Notifications", "done, WakaTime hook"),
        ("History-logs", "hist, logs"),
        ("Pkg-upgrade", "upgrade"),
    ]),
    ("Logging", "scrollback capture & paru/yay AUR wrappers", [
        ("Term-capture", "Kitty watcher, smart_exit scrollback"),
        ("Multiplexer", "tmux, zellij"),
        ("Pkg-logs", "paru/yay AUR log wrappers"),
    ]),
    ("Greeting", "fish_greeting & first-run welcome banner", [
        ("First-run", "welcome banner"),
        ("Greeting", "fish_greeting override"),
    ]),
    ("Master", "master off-switch: overrides all categories", []),
]

# label, kind, default-hint, description
SPONGE = [
    ("Delay", "int", "2", "entries kept before a failed command is purged"),
    ("Purge@exit", "bool", "false", "only purge history on shell exit"),
    ("Allow prev", "bool", "true", "keep commands that previously succeeded"),
    ("OK codes", "list", "0", "exit codes treated as success"),
    ("Extra secret", "list", "(none)", "extra patterns scrubbed from history"),
]

PATHS = [
    ("Log dir", "path", "~/.terminal_history", "scrollback capture directory"),
    ("Log max", "int", "100", "max scrollback files retained"),
    ("Dots path", "path", "(default)", "user-dots source directory"),
    ("Dots link", "bool", "on", "symlink ~/.config/.user-dots/fish"),
]

PAGES = ["Universal", "Session", "Sponge", "Paths"]


def initial_state():
    """Seed the in-memory stub backend. Keys are (page, row-label)."""
    st = {}
    for page in ("Universal", "Session"):
        for label, _, _ in CATEGORIES:
            st[(page, label)] = "DEFAULT"
        st[(page, "Aliases")] = "ON"
        st[(page, "Auto-exec")] = "OFF"
        st[(page, "Integrations")] = "ON"
    for row in SPONGE:
        st[("Sponge", row[0])] = ""
    for row in PATHS:
        st[("Paths", row[0])] = ""
    st[("Paths", "Log dir")] = "~/logs/term"
    return st


def rows_for(page):
    """Row tuples (label, kind, hint, description) for a page."""
    if page in ("Universal", "Session"):
        return [(lbl, "tri", "DEFAULT", desc) for lbl, desc, _ in CATEGORIES]
    return SPONGE if page == "Sponge" else PATHS


def subcats_for(label):
    for lbl, _, subs in CATEGORIES:
        if lbl == label:
            return subs
    return []


def apply_filter(rows, needle):
    """Case-insensitive match over label and description."""
    if not needle:
        return rows
    n = needle.lower()
    return [r for r in rows if n in r[0].lower() or n in r[3].lower()]


def cycle(value, kind, forward):
    """Advance a value one step. Non-toggle kinds are edited, not cycled."""
    if kind == "tri":
        i = TRI.index(value) if value in TRI else 0
        return TRI[(i + (1 if forward else -1)) % len(TRI)]
    if kind == "bool":
        order = ("", "on", "off")
        i = order.index(value) if value in order else 0
        return order[(i + (1 if forward else -1)) % len(order)]
    return "" if not forward else value


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
    pairs = {
        C_FRAME: curses.COLOR_BLUE,
        C_TITLE: curses.COLOR_MAGENTA,
        C_SEL: curses.COLOR_CYAN,
        C_ON: curses.COLOR_GREEN,
        C_OFF: curses.COLOR_RED,
        C_DEF: curses.COLOR_YELLOW,
        C_DIM: curses.COLOR_BLACK,
        C_HINT: curses.COLOR_CYAN,
        C_BAR: curses.COLOR_WHITE,
    }
    for pair, fg in pairs.items():
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
    try:
        if y == h - 1 and x + len(text) >= w:
            if len(text) > 1:
                win.addstr(y, x, text[:-1], attr)
            win.insstr(y, w - 1, text[-1], attr)
        else:
            win.addstr(y, x, text, attr)
    except curses.error:
        pass


def ell(text, room):
    """Truncate with an ellipsis so a clipped description reads as clipped."""
    if room <= 0:
        return ""
    return text if len(text) <= room else text[: room - 1] + "…"


def badge(value, kind, hint):
    """Right-hand value cell plus its colour pair."""
    if kind == "tri":
        return {
            "ON": ("[      ON ]", C_ON),
            "OFF": ("[ OFF     ]", C_OFF),
        }.get(value, ("[ DEFAULT ]", C_DEF))
    if kind == "bool":
        return {
            "on": ("[      ON ]", C_ON),
            "off": ("[ OFF     ]", C_OFF),
        }.get(value, ("[ DEFAULT ]", C_DEF))
    return ((value, C_ON) if value else (hint, C_DIM))


class App:
    def __init__(self, stdscr):
        self.scr = stdscr
        self.state = initial_state()
        self.page = 0
        self.row = 0
        self.filter = ""
        self.mode = "nav"          # nav | filter | edit | help
        self.buf = ""              # filter/edit scratch buffer
        self.drill = None          # category label when inside sub-categories
        self.msg = "prototype — nothing is written to fish variables"
        self.row_hits = []         # screen-row → row-index, for mouse clicks

    # ── data helpers ──────────────────────────────────────────────────────
    @property
    def page_name(self):
        return PAGES[self.page]

    def visible_rows(self):
        if self.drill is not None:
            return [(lbl, "tri", "DEFAULT", desc)
                    for lbl, desc in subcats_for(self.drill)]
        return apply_filter(rows_for(self.page_name), self.filter)

    def current(self):
        rows = self.visible_rows()
        return rows[self.row] if rows else None

    def value_of(self, label):
        key = (self.drill or self.page_name, label)
        return self.state.get(key, "DEFAULT" if self.drill else "")

    def set_value(self, label, value):
        self.state[(self.drill or self.page_name, label)] = value

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
        title = " Opinionated Settings "
        put(scr, 0, 0, "┌" + "─" * (w - 2) + "┐", frame)
        put(scr, 0, 2, title, curses.color_pair(C_TITLE) | curses.A_BOLD)
        body_top, body_bot = 1, h - 3
        for y in range(body_top, body_bot + 1):
            put(scr, y, 0, "│", frame)
            put(scr, y, SIDEBAR_W + 1, "│", frame)
            put(scr, y, w - 1, "│", frame)
        put(scr, h - 2, 0, "├" + "─" * SIDEBAR_W + "┴" + "─" * (w - SIDEBAR_W - 3) + "┤", frame)
        put(scr, h - 1, 0, "│", frame)
        put(scr, h - 1, w - 1, "│", frame)

        self.draw_sidebar(body_top, body_bot)
        self.draw_detail(body_top, body_bot, w)
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
                shown = "/" + self.buf + "_"
                attr = curses.color_pair(C_HINT) | curses.A_BOLD
            elif self.filter:
                shown, attr = "/" + self.filter, curses.color_pair(C_HINT)
            else:
                shown, attr = "(none)", curses.color_pair(C_DIM)
            put(scr, y + 1, 2, shown, attr, SIDEBAR_W - 2)

    def draw_detail(self, top, bot, w):
        scr = self.scr
        left = SIDEBAR_W + 3
        width = w - left - 1
        rows = self.visible_rows()
        self.row_hits = []

        if self.drill is not None:
            put(scr, top, left, f"{self.drill} ▸ sub-categories",
                curses.color_pair(C_TITLE) | curses.A_BOLD, width)
            top += 1

        if not rows:
            put(scr, top, left, "no rows match", curses.color_pair(C_DIM), width)
            return

        # Two screen lines per row (value line + description), one blank between.
        per = 3
        capacity = max(1, (bot - top + 1) // per)
        first = max(0, min(self.row - capacity + 1, len(rows) - capacity))
        first = max(0, first)

        for i in range(first, min(len(rows), first + capacity)):
            label, kind, hint, desc = rows[i]
            y = top + (i - first) * per
            sel = i == self.row
            self.row_hits.append((y, i))
            self.row_hits.append((y + 1, i))

            if self.mode == "edit" and sel:
                cell, cattr = self.buf + "_", C_HINT
            else:
                cell, cattr = badge(self.value_of(label), kind, hint)
            cell = cell[: max(0, width)]

            lattr = curses.color_pair(C_SEL) | curses.A_BOLD if sel else curses.A_BOLD
            put(scr, y, left, ("▸ " if sel else "  ") + label, lattr, width - len(cell) - 2)
            put(scr, y, left + width - len(cell), cell,
                curses.color_pair(cattr) | (curses.A_BOLD if sel else 0))
            put(scr, y + 1, left + 4, ell(desc, width - 4), curses.color_pair(C_DIM), width - 4)
            if y + 2 <= bot and i + 1 < min(len(rows), first + capacity):
                put(scr, y + 2, left, "─" * width, curses.color_pair(C_FRAME) | curses.A_DIM)

    def draw_status(self, h, w):
        if self.mode == "edit":
            keys = "⏎ commit   Esc cancel"
        elif self.mode == "filter":
            keys = "⏎ apply   Esc clear"
        elif self.drill is not None:
            keys = "↑↓ move  ←→ set  Esc back  ? help  q quit"
        elif w >= 90:
            keys = "↑↓ move  ←→ set  ⏎ drill/edit  Tab page  / filter  ? help  q quit"
        else:
            keys = "↑↓ ←→ ⏎  Tab pg  / filter  ? help  q quit"
        # Reserve the final column for the frame; put() refuses to write the
        # bottom-right cell anyway, so anything past w-2 is silently lost.
        avail = w - 4
        put(self.scr, h - 1, 2, keys, curses.color_pair(C_BAR) | curses.A_BOLD, avail)
        room = avail - len(keys) - 3
        if self.msg and room > 8:
            put(self.scr, h - 1, 2 + len(keys) + 3, ell(self.msg, room),
                curses.color_pair(C_DIM), room)

    def draw_help(self, h, w):
        lines = [
            "",
            "  Navigation",
            "    ↑ ↓ / k j      move between rows",
            "    Tab / ⇧Tab     next / previous page",
            "    ⏎              drill into sub-categories, or edit a value",
            "    Esc            leave sub-categories / cancel",
            "",
            "  Values",
            "    ← → / h l      cycle DEFAULT → ON → OFF",
            "    ⏎              inline edit (int, list and path rows)",
            "",
            "  Other",
            "    /              live filter over label and description",
            "    mouse          click a row to select, click its value to cycle",
            "    ?              toggle this overlay",
            "    q              quit",
            "",
            "  Prototype: curses render engine, stubbed backend.",
            "",
        ]
        bw = min(w - 4, max(len(x) for x in lines) + 4)
        bh = min(h - 2, len(lines) + 2)
        y0, x0 = (h - bh) // 2, (w - bw) // 2
        win = curses.newwin(bh, bw, y0, x0)
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
                row = self.current()
                if row:
                    self.set_value(row[0], self.buf)
                    self.msg = f"{row[0]} = {self.buf or '(cleared)'}"
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

        if key == "q":
            return False
        if key == "?":
            self.mode = "help"
        elif ch in (curses.KEY_DOWN,) or key == "j":
            self.row = (self.row + 1) % max(1, len(rows))
        elif ch in (curses.KEY_UP,) or key == "k":
            self.row = (self.row - 1) % max(1, len(rows))
        elif ch in (curses.KEY_RIGHT,) or key == "l":
            self.bump(True)
        elif ch in (curses.KEY_LEFT,) or key == "h":
            self.bump(False)
        elif ch == 9:  # Tab
            if self.drill is None:
                self.page = (self.page + 1) % len(PAGES)
                self.row = 0
        elif ch == curses.KEY_BTAB:
            if self.drill is None:
                self.page = (self.page - 1) % len(PAGES)
                self.row = 0
        elif key == "/":
            if self.drill is None:
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
        label, kind = row[0], row[1]
        if kind == "tri" and self.drill is None and subcats_for(label):
            self.drill, self.row = label, 0
            for sub in subcats_for(label):
                self.state.setdefault((label, sub[0]), "DEFAULT")
        elif kind in ("int", "list", "path"):
            self.mode, self.buf = "edit", self.value_of(label)
        else:
            self.bump(True)

    def bump(self, forward):
        row = self.current()
        if not row:
            return
        label, kind = row[0], row[1]
        if kind in ("tri", "bool"):
            new = cycle(self.value_of(label), kind, forward)
            self.set_value(label, new)
            self.msg = f"{label} = {new or 'DEFAULT'}"
        elif not forward:
            self.set_value(label, "")
            self.msg = f"{label} cleared to default"

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
                return
            if not self.handle(ch):
                return


# ╭──────────────────────────────────────────────────────────────────────────╮
# │ Entry points                                                             │
# ╰──────────────────────────────────────────────────────────────────────────╯

def self_test():
    """Exercise the pure logic. No terminal required."""
    st = initial_state()
    assert st[("Universal", "Aliases")] == "ON"
    assert st[("Universal", "Overrides")] == "DEFAULT"

    assert cycle("DEFAULT", "tri", True) == "ON"
    assert cycle("ON", "tri", True) == "OFF"
    assert cycle("OFF", "tri", True) == "DEFAULT"
    assert cycle("DEFAULT", "tri", False) == "OFF"
    assert cycle("", "bool", True) == "on"

    rows = rows_for("Universal")
    assert len(rows) == len(CATEGORIES)
    assert rows_for("Sponge") is SPONGE

    hits = apply_filter(rows, "log")
    assert [r[0] for r in hits] == ["Logging"], hits
    # Matches on description, not just label.
    assert [r[0] for r in apply_filter(rows, "starship")] == ["Overrides"]
    assert apply_filter(rows, "") == rows
    assert apply_filter(rows, "zzz") == []

    assert len(subcats_for("Aliases")) == 6
    assert subcats_for("Master") == []

    assert badge("ON", "tri", "")[1] == C_ON
    assert badge("", "path", "~/x")[0] == "~/x"
    assert badge("/tmp", "path", "~/x")[0] == "/tmp"

    assert ell("abcdef", 10) == "abcdef"
    assert ell("abcdef", 4) == "abc…"
    assert ell("abcdef", 0) == ""

    print("self-test OK")
    return 0


def main():
    if "--self-test" in sys.argv:
        return self_test()
    if "-h" in sys.argv or "--help" in sys.argv:
        print(__doc__ or "config-settings-tui.py [--self-test]")
        return 0

    def boot(stdscr):
        init_colors()
        App(stdscr).run()

    curses.wrapper(boot)
    return 0


if __name__ == "__main__":
    sys.exit(main())
