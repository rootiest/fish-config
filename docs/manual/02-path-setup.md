---
title: Path Setup
manTitle: 2. PATH SETUP
sidebar:
  order: 2
helpKeywords:
- path
---

Directories prepended to PATH in this order (first wins):

    ~/.local/bin              Standard user-local executables
    ~/Applications            User-installed standalone apps
    ~/scripts                 Personal shell scripts
    ~/bin                     Cargo binaries (appended — lowest priority)
    $BUN_INSTALL/bin          Bun runtime and global packages
    $NPM_CONFIG_PREFIX/bin    Global npm packages
    ~/.lmstudio/bin           LM Studio CLI
    ~/.resend/bin             Resend CLI
    ~/.fzf/bin                fzf binary (git-installed)

Cargo binaries are intentionally appended (lowest priority) to avoid
shadowing system-installed Rust tools.

---
