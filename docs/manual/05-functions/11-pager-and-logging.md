---
title: Pager and Logging
manTitle: 5.11 Pager and Logging
sidebar:
  order: 11
helpKeywords:
- logging
---

## logs

    Synopsis:  logs [-c <category>]
    Interactively browses terminal log files sorted newest-first using fzf.

      -c/--category  Filter to: scrollback, paru, or yay

    Keybindings inside the fzf browser:
      Enter    Open in $PAGER
      Ctrl+E   Open in $EDITOR
      Ctrl+D   Delete (with confirmation)
      ?        Toggle keybind help overlay

    Paru and yay logs open in ov with syntax highlighting and sticky section
    headers. Scrollback logs open in ov with per-command sticky prompt headers
    based on OSC 133 markers.

    logs
    logs -c paru
    logs -c scrollback

## smart_exit

    Synopsis:  smart_exit [-n]
    Closes the shell session. In Kitty, captures the terminal scrollback to
    a timestamped log file in $SCROLLBACK_HISTORY_DIR before exiting.
    Automatically prunes the oldest logs when the count exceeds
    $SCROLLBACK_HISTORY_MAX_FILES.

      -n/--no-log  Exit without saving a scrollback log

    The exit builtin is wired to smart_exit for interactive sessions.
    Typing exit or Ctrl+D behaves identically to smart_exit.

    smart_exit
    smart_exit --no-log

---
