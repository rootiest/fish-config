---
title: File and Directory
manTitle: 5.1 File and Directory
sidebar:
  order: 1
helpKeywords:
- files
---

## cat

    Synopsis:  cat [args...]
    Wraps bat for files with syntax highlighting and line numbers.
    Passes directories to ls. Falls back to /usr/bin/cat.

    cat README.md
    cat ~/projects/myapp

## copy

    Synopsis:  copy <source> <dest>
    Wraps cp, stripping trailing slashes from source directories to
    prevent unintended nesting inside the destination.

    copy ./mydir/ ~/backup    # copies mydir INTO backup, not backup/mydir/

## du

    Synopsis:  du [--disk|--dir|--dua] [args...]
    Smart disk-usage dispatcher:
      --disk  force duf  (disk-level free/used overview)
      --dir   force dust (per-directory tree breakdown)
      --dua   force dua  (fast space analyzer)
    Without flags, routes to the most appropriate tool by context.

    du ~/Downloads
    du --disk

## dusize

    Synopsis:  dusize [dir]
    Human-readable disk usage for a directory via du -sh. Defaults to cwd.

    dusize ~/Videos

## lD

    Synopsis:  lD [args...]
    Lists directories only in long format with icons. Uses eza, falls back
    to lsd, then system ls.

    lD ~/projects

## ls

    Synopsis:  ls [args...]
    Lists files in long format with icons and hyperlinks. Uses eza, falls
    back to lsd, then system ls.

    ls
    ls -a ~/projects

## lsr

    Synopsis:  lsr [args...]
    Lists files sorted by modification time, oldest first. Uses eza.

## lss

    Synopsis:  lss [args...]
    Lists files sorted by size with gradient color scaling. Uses eza.

## lstree

    Synopsis:  lstree [args...]
    Full recursive tree view with icons. Uses eza.

    lstree ~/projects/myapp

## lt

    Synopsis:  lt [args...]
    Tree view limited to depth 2 with icons. Uses eza.

    lt ~/projects

## ltr

    Synopsis:  ltr [args...]
    Lists files sorted by modification time, oldest first, long format with
    age-based gradient scaling. Uses eza.

## lx

    Synopsis:  lx [args...]
    Lists files sorted by extension, long format. Uses eza.

## mkdir

    Synopsis:  mkdir [args...]
    Interactive mkdir that prints a tree of created directories.
    Falls back to mkdir -p silently.

    mkdir ~/projects/myapp/src

## mkcd

    Synopsis:  mkcd [-s] <dir>
    Creates a directory (including parents) and cd into it. Prints a tree
    of created dirs by default; -s/--silent suppresses output.

    mkcd ~/projects/newapp/src

## poke

    Synopsis:  poke <file> [file...]
    Creates files via touch, automatically creating any missing parent
    directories first.

    poke ~/projects/new/src/main.fish

## rm

    Synopsis:  rm [-e [opts] | -S | args...]
    Safe rm wrapper routing to trash:

      (no args)   List current trash contents
      -e/--empty  Empty the trash (pass options to trash-empty)
      -S/--secure Permanently delete via rm -rf + fstrim (irreversible)
      -r/-R/--recursive  Move to trash
      <paths>     Move to trash (safe delete)

    Falls back to /usr/bin/rm when trash is unavailable.

    rm file.txt           # moves to trash
    rm -e                 # empty trash
    rm -S sensitive.pem   # permanent delete

## rg

    Synopsis:  rg [args...]
    In Kitty, wraps ripgrep with --hyperlink-format=kitty so search
    results are clickable file links in the terminal. Falls back to
    system rg in any other terminal. All other arguments pass through
    unchanged.

    rg "fish_greeting" ~/.config/fish/
    rg -l "TODO" ~/projects/myapp

## scrub

    Synopsis:  scrub [-a] [-d] [-h]
    Recursively removes OS metadata, editor artifacts, compiler output,
    and dev caches using fd.

      -a/--aggressive  Also removes node_modules, logs, .cache, IDE dirs,
                       AI session artifacts
      -d/--dry-run     Print what would be removed without deleting

    scrub
    scrub -a
    scrub -d

---
