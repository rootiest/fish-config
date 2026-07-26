---
title: Miscellaneous
manTitle: 5.14 Miscellaneous
sidebar:
  order: 14
helpKeywords:
- miscfns
---

## config-help

    Synopsis:  config-help [SECTION]
               config-help --html
               config-help [SECTION] --man
               config-help -h | --help

    Opens the offline fish shell configuration manual. Without flags, opens
    the Markdown source in the best available pager (ov > bat > man > less >
    cat). If SECTION is given, jumps to the first heading matching that
    keyword (case-insensitive; checks fish-config.index aliases first).

    Flags:
      --html / -w   Open the published documentation website
                    (https://fish-config-docs.pages.dev/) in the default
                    browser via xdg-open. Deep links to a section aren't
                    supported; if SECTION is given, a note points you to the
                    site's search box instead.
      --man  / -m   Open docs/fish-config.1 via man -l directly.
                    If SECTION is given, jumps to the nearest match.
      --help / -h   Print usage and navigation key reference.

    config-help keybindings
    config-help pkg
    config-help --html
    config-help --man
    config-help pkg --man

    Also available as: help config [SECTION] [FLAGS]

## open-url

    Synopsis:  open-url [-s|--silent] [-v|--verbose] <url>
               open-url -h | --help

    Opens a URL or file:// URI in the best available graphical web browser,
    backgrounded so it never blocks the terminal. Resolves a real browser
    binary rather than deferring to xdg-open, whose MIME dispatch can hand
    local text/html files to non-browser apps (e.g. ebook readers).

    Silent by default: prints nothing on success (errors always go to
    stderr). Pass --verbose / -v to report which browser is launched;
    --silent / -s is accepted for explicitness.

    Resolution order:
      1. $fish_help_browser  (explicit override)
      2. $BROWSER            (validated; errors if not a command)
      3. xdg-mime default handler for x-scheme-handler/https
      4. First known browser binary found in a built-in list
      5. xdg-open            (last resort)

    open-url https://git.rootiest.dev/rootiest/fish-config
    open-url -v https://fish-config-docs.pages.dev/

    Used internally by config-help --html.

    Typo abbreviation: url-open (expands to open-url on space/enter).

## repo-open

    Synopsis:  repo-open [-p|--print] [-r|--root]
               repo-open -h | --help

    Opens the web page for the current repository's `origin` remote in a
    browser (via open-url). Deep-links to the current branch when it exists
    on the remote — falling back to the remote's default branch (main/master)
    otherwise — and to the current sub-directory when run below the repo root.

    The remote URL is normalized from HTTPS and SSH/scp forms
    (git@host:owner/repo.git, ssh://…, https://…). The web path layout is
    provider-specific; the provider is resolved in order:

      1. git config browse.provider   (per-repo or --global override)
      2. Hostname heuristic           (github / gitlab / gitea / bitbucket;
                                        codeberg → gitea)
      3. Default: github-style layout

    Self-hosted hosts the heuristic can't classify (a Gitea/GitLab instance
    on a custom domain) need a one-time override:

      git config browse.provider gitea

    Flags:
      --print / -p   Print the resolved URL instead of opening it.
      --root  / -r   Ignore the current sub-directory; link to the repo root.
      --help  / -h   Show usage.

    repo-open
    repo-open --print
    repo-open --root

    Typo abbreviation: open-repo (expands to repo-open on space/enter).

## config-update

    Synopsis:  config-update [-h] [-n] [-f]

    Pulls the latest fish configuration from the upstream repository
    (https://git.rootiest.dev/rootiest/fish-config.git) into ~/.config/fish.
    The remote URL is hard-coded, so this works on fresh clones with no git
    remote configured. All git output is suppressed; colored messages report
    fetch and merge status. After a successful pull, run `exec fish` to
    reload.

    Flags:
      --dry-run / -n   Fetch and show available commits without applying them.
      --force  / -f    Stash local changes, pull, then restore the stash.
      --help   / -h    Show usage.

    config-update
    config-update --dry-run
    config-update --force

## config-settings

    Synopsis:  config-settings [-h]

    Opens an interactive TUI for managing fish configuration settings across
    four pages, without having to type or remember variable names. Tab cycles
    forward through the pages; Shift-Tab cycles backward.

      Universal — opinionated category toggles (C1–C6) + master, persistent (set -U)
      Session   — the same toggles, current shell only (set -g)
      Sponge    — sponge history-scrubbing settings: delay, successful exit
                  codes, purge-only-on-exit, allow-previously-successful, and
                  extra sensitive variable-name tokens
      Paths     — scrollback log directory, scrollback max files, the
                  user-dots path, and the user-dots convenience symlink toggle
                  (Dots link)

    Toggle rows use ← → (or h/l) along an OFF ← DEFAULT → ON scale; DEFAULT
    erases the variable so the master switch / built-in default applies. Value
    rows (the path/int/list settings on the Sponge and Paths pages) use Enter to
    edit inline; ← / h clears the value back to its default. List rows (e.g.
    Extra secret, OK codes) accept values separated by commas and/or whitespace
    — "A, B", "A,B" and "A B" all yield the same two entries. Changes apply
    immediately. Always available regardless of the __fish_config_opinionated
    master state.

    The Sponge and Paths pages always write universal variables — these are
    persistent, set-and-forget settings with no per-session scope. Editing a
    scrollback row updates both the __fish_scrollback_history_* source-of-truth
    variables and the exported SCROLLBACK_HISTORY_* mirrors, so the AUR/tmux/
    zellij log wrappers (which read the exported names) see the change in the
    running session.

    The panel adapts to the terminal width automatically, selecting from
    four layout tiers (with a 6-column buffer on each side before stepping
    up to the next tier) and horizontally centering the box. The panel
    redraws within ~0.3 s of a terminal resize with no keypress required.

      COLUMNS >= 90  →  78-wide panel (most detail)
      COLUMNS >= 86  →  74-wide panel
      COLUMNS >= 82  →  70-wide panel
      COLUMNS  < 82  →  52-wide panel (default)

    Navigation:
      ↑ ↓ / k j     Move cursor
      ← → / h l     Toggle rows: OFF ← DEFAULT → ON
      ←  / h        Value rows: clear to default
      Enter         Value rows: edit inline (Sponge / Paths pages)
      Tab / S-Tab   Next / previous page
      q / Escape    Exit

    Flags:
      --help / -h   Show usage.

    config-settings

## config-toggle (deprecated)

    Deprecated alias for config-settings. Prints a deprecation notice to
    stderr, then delegates all arguments to config-settings.

    config-toggle

## bash

    Synopsis:  bash [args...]
    Switches to bash, with XDG config applied. On exit, $SHELL is reset
    back to fish.

## bd-pull

    Synopsis:  bd-pull <owner/repo>
    Fetches unlinked Gitea issues and creates local Beads entries, updating
    issue titles with the assigned Beads IDs.
    Requires $GITEA_TOKEN and $GITEA_URL to be set.

    bd-pull rootiest/fish-config

## cheat

    Synopsis:  cheat <topic> [args...]
    Displays a colorized cheatsheet using cheat -c, falls back to tldr,
    then man.

    cheat tar
    cheat git

## cffetch / ffetch

    Synopsis:  cffetch [args...]  /  ffetch [args...]
    Clears the screen and displays system information via fastfetch with
    the custom config at ~/.fastfetch.jsonc. Falls back to neofetch.

## dockup

    Synopsis:  dockup [-h] [directory]
    Pulls latest Docker images, restarts services in the given Docker
    Compose project, and prunes dangling images.

    dockup ~/myapp

## joplin

    Synopsis:  joplin [args...]
    Runs the Joplin CLI with Node.js deprecation warnings suppressed.

    joplin ls

## ld

    Synopsis:  ld
    Launches lazydocker targeting the currently active Docker context,
    detected via docker context inspect.

## replay

    Synopsis:  replay <commands>
    Runs Bash commands and replays any resulting changes to environment
    variables, aliases, and the working directory back into the current
    Fish session. Useful for sourcing Bash scripts.

    replay "source ~/.bashrc"
    replay "export FOO=bar"

## kitty-logging

    Synopsis:  kitty-logging [install|uninstall|status|dismiss] [-h]

    Manages the Kitty scrollback watcher that powers C5 logging. Ships a
    canonical watcher and symlinks it into the Kitty config directory (so it
    always tracks the source), wiring it into kitty.conf through a
    sentinel-marked managed block. Commenting out any conflicting watcher line
    avoids double-capture.

    Commands:
      install    Symlink the watcher and add the managed block
      uninstall  Remove the managed block and the watcher symlink
      status     Show wiring, installed watcher version, and C5 state
      dismiss    Stop the per-session setup reminder

    Runtime capture stays governed by the C5 .logging_disabled sentinel, so
    disabling __fish_config_op_logging makes the watcher inert without
    uninstalling. Install affects new Kitty windows only.

    Example:
      kitty-logging install
      kitty-logging status

## tmux-clean

    Synopsis:  tmux-clean
    Kills all detached (unattached) tmux sessions, leaving attached ones
    running.

## wake-lock

    Synopsis:  wake-lock <command> [args...]
    Runs a command under systemd-inhibit, preventing the system from going
    idle or sleeping until the command completes.

    wake-lock rsync -avz src/ dest/

---
