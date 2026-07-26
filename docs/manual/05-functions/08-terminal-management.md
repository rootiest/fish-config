---
title: Terminal Management
manTitle: 5.8 Terminal Management
sidebar:
  order: 8
helpKeywords:
- terminal-mgmt
---

## tab

    Synopsis:  tab [args...]
    Opens a new tab in Kitty (kitty @ launch --type=tab), WezTerm
    (wezterm cli spawn), or Konsole. Uses current working directory,
    or $cdto if set.

    tab

## split

    Synopsis:  split [-h|-v] [command...]
    Opens a new pane in Kitty or WezTerm, optionally running a command.

      -h/--horizontal  (default) Split below
      -v/--vertical    Split to the right

    split
    split -v nvim README.md

## spwin

    Synopsis:  spwin [args...]
    Spawns a new terminal OS window in Kitty (via spawn-window.sh or
    kitty @ launch --type=os-window) or WezTerm (wezterm cli spawn --new-window).

## detach

    Synopsis:  detach [-h] [--version] <command> [args...]
    Runs a command fully detached via nohup with stdout/stderr discarded.
    The command survives the current session.

    detach rsync -a ./data remote:/backup/

## bkg

    Synopsis:  bkg <command> [args...]
    Launches a command in the background via nohup with output discarded.
    Simpler than detach; no version flag.

    bkg firefox

## ssh

    Synopsis:  ssh [args...]
    In Kitty, wraps ssh with kitten ssh for better terminal integration
    (multiplexing, copy/paste support). Falls back to system ssh elsewhere.

    ssh user@host

---
