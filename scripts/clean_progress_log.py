#!/usr/bin/env python3
# Copyright (C) 2026 Rootiest
# SPDX-License-Identifier: AGPL-3.0-or-later
#
# SYNOPSIS
#   clean_progress_log.py < typescript.raw > clean.log
#
# DESCRIPTION
#   Renders a script(1) typescript containing terminal animations (pacman/paru
#   download progress bars, which repaint in place using carriage returns and
#   ANSI cursor-movement/erase sequences) down to a clean, static log that shows
#   only the final state of each line. SGR color sequences are preserved so the
#   output still renders with color in pagers such as ov, bat, or less -R.
#
#   It implements a minimal terminal screen-buffer emulator: it replays the
#   cursor movements against an in-memory grid of cells, so the concatenated
#   redraw frames collapse to the final frame exactly as a real terminal would
#   display them. script(1) "Script started/done" header and footer lines are
#   dropped.
#
# RETURNS
#   0  Always (best-effort; unparseable bytes are passed through as text).
#
# EXAMPLE
#   script -q -e -c 'paru -Syu' raw.log
#   clean_progress_log.py < raw.log > clean.log

import re
import sys

# One CSI sequence: ESC [ <params> <final>.  Covers SGR (m), cursor moves
# (A/B/C/D/E/F/G/H/f), erases (J/K), and private modes (?25l/h) alike.
_CSI = re.compile(r"\x1b\[([0-9;?]*)([A-Za-z])")
# OSC sequence (e.g. window title): ESC ] ... BEL  or  ESC ] ... ESC \
_OSC = re.compile(r"\x1b\][^\x07\x1b]*(?:\x07|\x1b\\)")
# script(1) header/footer lines to drop from the final render.
_SCRIPT_LINE = re.compile(r"^Script (started|done) on ")


class Screen:
    """A minimal, unbounded-height terminal emulator.

    Each cell is a [sgr, char] pair, where sgr is the full active SGR escape
    string in effect when the character was written ('' means default). The
    grid grows downward as needed; relative cursor moves index into it, so
    in-place repaints overwrite earlier frames just like a real terminal.
    """

    def __init__(self):
        self.rows = [[]]
        self.row = 0
        self.col = 0
        self.sgr = ""

    def _ensure_row(self, r):
        while len(self.rows) <= r:
            self.rows.append([])

    def _ensure_col(self, c):
        row = self.rows[self.row]
        while len(row) <= c:
            row.append(["", " "])

    def write_char(self, ch):
        self._ensure_row(self.row)
        self._ensure_col(self.col)
        self.rows[self.row][self.col] = [self.sgr, ch]
        self.col += 1

    def newline(self):
        # script(1) typescripts always emit CRLF (the PTY's ONLCR translates
        # LF to CRLF on output), so a bare LF starts a fresh line. Reset the
        # column to avoid "staircase" artifacts if a bare LF ever appears.
        self.row += 1
        self.col = 0
        self._ensure_row(self.row)

    def carriage_return(self):
        self.col = 0

    def backspace(self):
        if self.col > 0:
            self.col -= 1

    def tab(self):
        self.col = (self.col // 8 + 1) * 8

    def set_sgr(self, params):
        # Treat a bare reset (ESC[0m / ESC[m) as clearing all attributes;
        # otherwise adopt the new full sequence. pacman always emits complete
        # attribute sets, so replacement (rather than merging) is exact here.
        if params in ("", "0"):
            self.sgr = ""
        else:
            self.sgr = "\x1b[" + params + "m"

    def csi(self, params, final):
        if final == "m":
            self.set_sgr(params)
            return
        # Numeric argument (default 1 for moves, 0 for erases).
        nums = [int(p) for p in params.split(";") if p.isdigit()]
        n = nums[0] if nums else None
        if final == "A":
            self.row = max(0, self.row - (n or 1))
        elif final == "B" or final == "E":
            self.row += (n or 1)
            self._ensure_row(self.row)
            if final == "E":
                self.col = 0
        elif final == "F":
            self.row = max(0, self.row - (n or 1))
            self.col = 0
        elif final == "C":
            self.col += (n or 1)
        elif final == "D":
            self.col = max(0, self.col - (n or 1))
        elif final == "G":
            self.col = (n or 1) - 1
        elif final in ("H", "f"):
            self.row = (nums[0] - 1) if len(nums) >= 1 else 0
            self.col = (nums[1] - 1) if len(nums) >= 2 else 0
            self._ensure_row(self.row)
        elif final == "K":
            self._erase_line(n or 0)
        elif final == "J":
            self._erase_display(n or 0)
        # Any other final (private modes like ?25l/h, etc.) is ignored.

    def _erase_line(self, mode):
        self._ensure_row(self.row)
        row = self.rows[self.row]
        if mode == 0:  # cursor to end of line
            del row[self.col:]
        elif mode == 1:  # start of line to cursor
            for c in range(min(self.col + 1, len(row))):
                row[c] = ["", " "]
        elif mode == 2:  # whole line
            row.clear()

    def _erase_display(self, mode):
        if mode == 2:  # whole screen
            self.rows = [[]]
            self.row = 0
            self.col = 0
        elif mode == 0:  # cursor to end of screen
            self._erase_line(0)
            del self.rows[self.row + 1:]

    def feed(self, data):
        i = 0
        n = len(data)
        while i < n:
            ch = data[i]
            if ch == "\x1b":
                m = _CSI.match(data, i)
                if m:
                    self.csi(m.group(1), m.group(2))
                    i = m.end()
                    continue
                m = _OSC.match(data, i)
                if m:
                    i = m.end()
                    continue
                # Charset designators (ESC ( B etc.) and other 2-char escapes.
                if i + 1 < n and data[i + 1] in "()":
                    i += 3
                else:
                    i += 2
                continue
            if ch == "\n":
                self.newline()
            elif ch == "\r":
                self.carriage_return()
            elif ch == "\b":
                self.backspace()
            elif ch == "\t":
                self.tab()
            elif ch == "\x07":  # bell
                pass
            else:
                self.write_char(ch)
            i += 1

    def render(self):
        out_lines = []
        for row in self.rows:
            last_sgr = ""
            buf = []
            for sgr, ch in row:
                if sgr != last_sgr:
                    if sgr == "":
                        buf.append("\x1b[0m")
                    else:
                        buf.append(sgr)
                    last_sgr = sgr
                buf.append(ch)
            if last_sgr != "":
                buf.append("\x1b[0m")
            line = "".join(buf)
            # Strip trailing whitespace (and any trailing reset that follows it).
            line = re.sub(r"[ \t]+(\x1b\[0m)?$", r"\1", line)
            out_lines.append(line)
        # Drop script(1) header/footer lines (compare against de-escaped text).
        kept = []
        for line in out_lines:
            plain = _CSI.sub("", line)
            if _SCRIPT_LINE.match(plain):
                continue
            kept.append(line)
        # Trim trailing blank lines.
        while kept and kept[-1].strip() == "":
            kept.pop()
        return "\n".join(kept) + ("\n" if kept else "")


def main():
    data = sys.stdin.buffer.read().decode("utf-8", "replace")
    screen = Screen()
    screen.feed(data)
    sys.stdout.write(screen.render())


if __name__ == "__main__":
    main()
