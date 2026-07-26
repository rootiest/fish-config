---
title: Git and Version Control
manTitle: 5.4 Git and Version Control
sidebar:
  order: 4
helpKeywords:
- git
---

## auto-pull

    Synopsis:  auto-pull [list]
               auto-pull add [PATH]
               auto-pull remove <NAME|PATH>
               auto-pull status

    Manages the registry of repositories that are background fast-forwarded
    when you enter them (see "Auto-pull fast-forward" under the C2 component
    reference). The fish-config repo is always covered as a baseline. The
    registry is machine-local at `$__fish_user_dots_path/auto-pull.list` (defaults
    to `~/.config/.user-dots/fish/auto-pull.list`), one absolute path per line,
    and is never committed. Registry management works
    even when C2 auto-execution is disabled; only the background sync is gated.

      list               Show registered repos (default)
      add [PATH]         Register PATH's git root (default: current repo)
      remove <NAME|PATH> Unregister by basename or exact path
      status             Show enabled/disabled state, repo count, list path

    cd ~/src/qmk_firmware; and auto-pull add
    auto-pull add ~/work/api
    auto-pull list
    auto-pull remove qmk_firmware

## branch

    Synopsis:  branch <branch_name>
    Switches to a local branch, or creates it if it does not exist.

    branch feature/new-ui

## gi

    Synopsis:  gi [-h] [-b] [-p] [-s] [-l] [targets...]
    Generates .gitignore content from the gitignore.io API with MD5-based
    deduplication (patterns already present are not re-appended).

      -b/--boilerplate  Append generic boilerplate first
      -p/--prompt       Prompt interactively for targets
      -s/--stdout       Print to stdout instead of appending to .gitignore
      -l/--list         List all available targets
      targets           Comma-separated or space-separated target names

    gi python,venv
    gi -b -p
    gi -s node > .gitignore

## git-clean

    Synopsis:  git-clean [-f]
    Fetches and prunes the remote, fast-forwards the current branch, then
    deletes local branches whose remote tracking branch has been deleted.
    Switches to main/master automatically if the current branch is orphaned.

      -f/--force  Force-delete unmerged branches too

    git-clean
    git-clean --force

## gitup

    Synopsis:  gitup [args...]
    Fetches updates from the remote and shows git status. Extra args are
    forwarded to git fetch.

    gitup
    gitup --all

## gitui

    Synopsis:  gitui [args...]
    Launches gitui with the Catppuccin Frappe theme pre-applied.

## hist

    Synopsis:  hist
    Searches shell history with fzf, inserts the selection into the command
    line, and copies it to the clipboard via wl-copy.

---
