---
title: Clipboard
manTitle: 5.9 Clipboard
sidebar:
  order: 9
helpKeywords:
- clipboard
---

## y

    Synopsis:  y [text...]
    Copies text to the clipboard via wl-copy (Wayland) or xclip (X11).
    Reads from stdin if no arguments given.

    y "hello world"
    ls | y
    cat file.txt | y

## p

    Synopsis:  p [args...]
    Outputs clipboard contents to stdout.

    p | grep foo
    p > file.txt

## paste

    Alias for p. Identical behaviour.

---
