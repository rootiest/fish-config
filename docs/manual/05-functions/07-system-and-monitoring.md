---
title: System and Monitoring
manTitle: 5.7 System and Monitoring
sidebar:
  order: 7
helpKeywords:
- system
---

## top

    Synopsis:  top [args...]
    Launches btop as a modern resource monitor. Falls back to system top.

## swapstat

    Synopsis:  swapstat
    Displays a colorized memory report: kernel swappiness, zRAM compression
    ratio, zRAM device details, and active swap priorities.

## sbver

    Synopsis:  sbver [--brief]
    Verifies Secure Boot signatures on all EFI binaries tracked by sbctl.
    Color-codes results: green checkmark (verified), red X (unsigned).
    Prints a pass/fail summary.

      --brief  Suppress per-file output, show only the summary

    sbver
    sbver --brief

## ports

    Synopsis:  ports
    Lists active TCP listeners with lsof, showing port/address without
    hostname resolution.

## screensleep

    Synopsis:  screensleep
    Turns off the display via KDE PowerDevil's "Turn Off Screen" action,
    invoked through busctl.

## lock

    Synopsis:  lock
    Locks the current desktop session using loginctl lock-session.

## sudo-toggle

    Synopsis:  sudo-toggle
    Toggles the sudo NOPASSWD rule on/off via /etc/sudoers.d/nofail-toggle.
    Useful for automated tasks that would otherwise require password entry.

## limine-edit

    Synopsis:  limine-edit
    Opens /boot/limine.conf in sudoedit, then automatically re-enrolls the
    config hash, runs CachyOS boot hooks, and re-signs Secure Boot files.
    Combines the edit and sign steps into a single command.

---
