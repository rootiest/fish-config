#!/usr/bin/env python3
# Copyright (C) 2026 Rootiest
# SPDX-License-Identifier: AGPL-3.0-or-later
# fish-config-watcher-version: 1
#
# Managed by fish-config `kitty-logging`, which symlinks this file into the
# Kitty config directory. The canonical source lives at
# ~/.config/fish/scripts/kitty-fish-config-watcher.py.

import datetime
import os
import re
from kitty.boss import Boss
from kitty.window import Window

_logged_windows: set[int] = set()


def save_scrollback_safely(window: Window) -> None:
    home = os.path.expanduser("~")
    xdg_config = os.environ.get("XDG_CONFIG_HOME", os.path.join(home, ".config"))
    sentinel = os.path.join(xdg_config, "fish", ".logging_disabled")
    if os.path.exists(sentinel):
        return
    if window.user_vars.get("logged_by_shell") == "true":
        return
    if window.id in _logged_windows:
        return

    snapshot_dir = os.environ.get(
        "SCROLLBACK_HISTORY_DIR", os.path.join(home, ".terminal_history")
    )
    max_files_str = os.environ.get("SCROLLBACK_HISTORY_MAX_FILES", "100")

    try:
        max_files = int(max_files_str)
    except ValueError:
        max_files = 100

    os.makedirs(snapshot_dir, exist_ok=True)

    # Safety filter: prevent TUI capture if an editor is focused
    try:
        foreground_processes = window.child.foreground_processes
        if foreground_processes:
            cmdline = foreground_processes[-1].get("cmdline") or [""]
            base_app = os.path.basename(cmdline[0])
            if re.match(r"^(nvim|vim|vi|nano|emacs|tmux)$", base_app):
                return
    except Exception:
        pass

    text = window.as_text(as_ansi=True, add_history=True)
    if not text.strip():
        return

    text_cleaned = re.sub(r"^\x1b\[38;2;[0-9;]*m", "", text)

    timestamp = datetime.datetime.now().strftime("%Y-%m-%d_%H-%M-%S")
    filename = os.path.join(snapshot_dir, f"scrollback_{timestamp}.log")

    try:
        with open(filename, "w", encoding="utf-8") as f:
            f.write(text_cleaned)
    except IOError:
        return

    _logged_windows.add(window.id)

    try:
        files = sorted(
            os.path.join(snapshot_dir, f)
            for f in os.listdir(snapshot_dir)
            if f.startswith("scrollback_") and f.endswith(".log")
        )
        for old in files[: max(0, len(files) - max_files)]:
            os.remove(old)
    except Exception:
        pass


def on_close(boss: Boss, window: Window, data: dict) -> None:
    save_scrollback_safely(window)


def on_quit(boss: Boss, window: Window, data: dict) -> None:
    if not data.get("confirmed"):
        return
    for win in boss.all_windows:
        save_scrollback_safely(win)
