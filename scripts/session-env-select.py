#!/usr/bin/env python3
# Copyright (C) 2026 Rootiest
# SPDX-License-Identifier: AGPL-3.0-or-later
#
# SYNOPSIS
#   session-env-select.py --catalog FILE --out FILE [--selected NAME]...
#
# DESCRIPTION
#   Checkbox picker behind `session-env select`, drawn with the stdlib
#   curses module like scripts/config-settings-tui.py. It reads the
#   session-env catalog (group, default, name, value, description; tab
#   separated), shows every variable under its group, and writes the names
#   left checked, one per line, to --out. It never touches fish or the
#   environment.d file: `session-env select` turns the answer into an
#   install.
#
#   Keys: up/down or k/j move, space toggles a variable (on a group row,
#   the whole group), a toggles the group of the current row, Enter saves,
#   q or Escape cancels. A cancel writes nothing and exits 1.
#
# EXIT STATUS
#   0  Saved
#   1  Cancelled
#   2  Usage error or unreadable catalog

import argparse
import curses
import sys


def load(path):
    rows = []
    with open(path, encoding="utf-8") as fh:
        for line in fh:
            line = line.rstrip("\n")
            if not line.strip() or line.lstrip().startswith("#"):
                continue
            f = line.split("\t")
            if len(f) < 5:
                continue
            rows.append({"group": f[0], "name": f[2], "value": f[3], "desc": f[4]})
    return rows


def build_items(rows):
    """Flat list of ('group', name) and ('var', idx) display items."""
    items = []
    seen = []
    for r in rows:
        if r["group"] not in seen:
            seen.append(r["group"])
    for g in seen:
        items.append(("group", g))
        for i, r in enumerate(rows):
            if r["group"] == g:
                items.append(("var", i))
    return items


def group_state(rows, checked, g):
    idx = [i for i, r in enumerate(rows) if r["group"] == g]
    on = sum(1 for i in idx if checked[i])
    if on == 0:
        return "[ ]"
    return "[x]" if on == len(idx) else "[-]"


def toggle_group(rows, checked, g):
    idx = [i for i, r in enumerate(rows) if r["group"] == g]
    new = not all(checked[i] for i in idx)
    for i in idx:
        checked[i] = new


def run(stdscr, rows, checked):
    curses.curs_set(0)
    items = build_items(rows)
    cur = 0
    top = 0
    while True:
        h, w = stdscr.getmaxyx()
        body = max(1, h - 3)
        if cur < top:
            top = cur
        if cur >= top + body:
            top = cur - body + 1
        stdscr.erase()
        try:
            draw(stdscr, rows, checked, items, cur, top, body, h, w)
        except curses.error:
            pass
        ch = stdscr.getch()
        if ch in (curses.KEY_UP, ord("k")):
            cur = max(0, cur - 1)
        elif ch in (curses.KEY_DOWN, ord("j")):
            cur = min(len(items) - 1, cur + 1)
        elif ch == curses.KEY_PPAGE:
            cur = max(0, cur - body)
        elif ch == curses.KEY_NPAGE:
            cur = min(len(items) - 1, cur + body)
        elif ch in (curses.KEY_HOME, ord("g")):
            cur = 0
        elif ch in (curses.KEY_END, ord("G")):
            cur = len(items) - 1
        elif ch == ord(" "):
            kind, ref = items[cur]
            if kind == "group":
                toggle_group(rows, checked, ref)
            else:
                checked[ref] = not checked[ref]
        elif ch == ord("a"):
            kind, ref = items[cur]
            g = ref if kind == "group" else rows[ref]["group"]
            toggle_group(rows, checked, g)
        elif ch in (10, 13, curses.KEY_ENTER):
            return True
        elif ch in (ord("q"), 27):
            return False


def draw(stdscr, rows, checked, items, cur, top, body, h, w):
    title = "session-env: choose the variables to export"
    stdscr.addnstr(0, 0, title, max(0, w - 1), curses.A_BOLD)
    for row in range(body):
        n = top + row
        if n >= len(items):
            break
        kind, ref = items[n]
        attr = curses.A_REVERSE if n == cur else 0
        if kind == "group":
            text = "%s %s" % (group_state(rows, checked, ref), ref)
            attr |= curses.A_BOLD
        else:
            r = rows[ref]
            box = "[x]" if checked[ref] else "[ ]"
            text = "    %s %-38s %s" % (box, r["name"], r["desc"])
        stdscr.addnstr(row + 1, 0, text, max(0, w - 1), attr)
    status = "space toggle   a group   enter save   q cancel"
    stdscr.addnstr(h - 1, 0, status, max(0, w - 1), curses.A_DIM)
    kind, ref = items[cur]
    if kind == "var":
        stdscr.addnstr(h - 2, 0, "value: %s" % rows[ref]["value"], max(0, w - 1))
    stdscr.refresh()


def main(argv):
    ap = argparse.ArgumentParser()
    ap.add_argument("--catalog", required=True)
    ap.add_argument("--out", required=True)
    ap.add_argument("--selected", action="append", default=[])
    try:
        args = ap.parse_args(argv)
    except SystemExit:
        return 2
    try:
        rows = load(args.catalog)
    except OSError as e:
        print("session-env-select: %s" % e, file=sys.stderr)
        return 2
    if not rows:
        print("session-env-select: empty catalog", file=sys.stderr)
        return 2
    checked = [r["name"] in set(args.selected) for r in rows]
    saved = curses.wrapper(run, rows, checked)
    if not saved:
        return 1
    with open(args.out, "w", encoding="utf-8") as fh:
        for r, on in zip(rows, checked):
            if on:
                fh.write(r["name"] + "\n")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
