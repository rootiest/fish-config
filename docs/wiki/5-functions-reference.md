# 5. FUNCTIONS REFERENCE

**Sections:** [Index](index.md) | [1. Configuration Variables](1-configuration-variables.md) | [2. Path Setup](2-path-setup.md) | [3. Key Bindings](3-key-bindings.md) | [4. Abbreviations](4-abbreviations.md) | **5. Functions Reference** | [6. Dependency Catalog](6-dependency-catalog.md) | [7. Customization](7-customization.md) | [8. Fisher Plugins](8-fisher-plugins.md) | [9. Installation](9-installation.md) | [10. Personalization](10-personalization.md) | [11. Viewing This Manual](11-viewing-this-manual.md)

---

## 5.1 File and Directory

### cat

    Synopsis:  cat [args...]
    Wraps bat for files with syntax highlighting and line numbers.
    Passes directories to ls. Falls back to /usr/bin/cat.

    cat README.md
    cat ~/projects/myapp

### copy

    Synopsis:  copy <source> <dest>
    Wraps cp, stripping trailing slashes from source directories to
    prevent unintended nesting inside the destination.

    copy ./mydir/ ~/backup    # copies mydir INTO backup, not backup/mydir/

### du

    Synopsis:  du [--disk|--dir|--dua] [args...]
    Smart disk-usage dispatcher:
      --disk  force duf  (disk-level free/used overview)
      --dir   force dust (per-directory tree breakdown)
      --dua   force dua  (fast space analyzer)
    Without flags, routes to the most appropriate tool by context.

    du ~/Downloads
    du --disk

### dusize

    Synopsis:  dusize [dir]
    Human-readable disk usage for a directory via du -sh. Defaults to cwd.

    dusize ~/Videos

### lD

    Synopsis:  lD [args...]
    Lists directories only in long format with icons. Uses eza, falls back
    to lsd, then system ls.

    lD ~/projects

### ls

    Synopsis:  ls [args...]
    Lists files in long format with icons and hyperlinks. Uses eza, falls
    back to lsd, then system ls.

    ls
    ls -a ~/projects

### lsr

    Synopsis:  lsr [args...]
    Lists files sorted by modification time, oldest first. Uses eza.

### lss

    Synopsis:  lss [args...]
    Lists files sorted by size with gradient color scaling. Uses eza.

### lstree

    Synopsis:  lstree [args...]
    Full recursive tree view with icons. Uses eza.

    lstree ~/projects/myapp

### lt

    Synopsis:  lt [args...]
    Tree view limited to depth 2 with icons. Uses eza.

    lt ~/projects

### ltr

    Synopsis:  ltr [args...]
    Lists files sorted by modification time, oldest first, long format with
    age-based gradient scaling. Uses eza.

### lx

    Synopsis:  lx [args...]
    Lists files sorted by extension, long format. Uses eza.

### mkdir

    Synopsis:  mkdir [args...]
    Interactive mkdir that prints a tree of created directories.
    Falls back to mkdir -p silently.

    mkdir ~/projects/myapp/src

### mkcd

    Synopsis:  mkcd [-s] <dir>
    Creates a directory (including parents) and cd into it. Prints a tree
    of created dirs by default; -s/--silent suppresses output.

    mkcd ~/projects/newapp/src

### poke

    Synopsis:  poke <file> [file...]
    Creates files via touch, automatically creating any missing parent
    directories first.

    poke ~/projects/new/src/main.fish

### rm

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

### rg

    Synopsis:  rg [args...]
    In Kitty, wraps ripgrep with --hyperlink-format=kitty so search
    results are clickable file links in the terminal. Falls back to
    system rg in any other terminal. All other arguments pass through
    unchanged.

    rg "fish_greeting" ~/.config/fish/
    rg -l "TODO" ~/projects/myapp

### scrub

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

## 5.2 Navigation

### cdi

    Synopsis:  cdi [query]
    Interactive directory picker combining zoxide frecency with fzf.
    Equivalent to zi.

    cdi myproject

### clone

    Synopsis:  clone [args...]
    Clone a git repository into a new Kitty window. Kitty-only.

    clone https://github.com/user/repo.git

### clonet

    Synopsis:  clonet [args...]
    Clone a git repository into a new Kitty tab. Kitty-only.

    clonet https://github.com/user/repo.git

---

## 5.3 Editors and Viewers

### edit

    Synopsis:  edit [args...]
    Opens files in nvim. Falls back to $EDITOR, nano, vi.

    edit ~/.config/fish/config.fish

### fc

    Synopsis:  fc [command_prefix]
    Edit the last shell command (or one matching a prefix) in $EDITOR,
    then execute the result. Bash-style fc behaviour.

    fc
    fc git

### less

    Synopsis:  less [args...]
    Pager wrapper with fallback chain: $PAGER -> ov -> less -> more -> cat.

    less /var/log/syslog

### rawfish

    Synopsis:  rawfish [args...]
    Launches Fish with NO_TMUX=1, bypassing any tmux auto-attach logic.
    Useful when you need a clean shell without session management.

### view

    Synopsis:  view [args...]
    Opens files in nvim read-only mode (-R). Falls back to less.

    view /etc/fstab

---

## 5.4 Git and Version Control

### branch

    Synopsis:  branch <branch_name>
    Switches to a local branch, or creates it if it does not exist.

    branch feature/new-ui

### gi

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

### git-clean

    Synopsis:  git-clean [-f]
    Fetches and prunes the remote, fast-forwards the current branch, then
    deletes local branches whose remote tracking branch has been deleted.
    Switches to main/master automatically if the current branch is orphaned.

      -f/--force  Force-delete unmerged branches too

    git-clean
    git-clean --force

### gitup

    Synopsis:  gitup [args...]
    Fetches updates from the remote and shows git status. Extra args are
    forwarded to git fetch.

    gitup
    gitup --all

### gitui

    Synopsis:  gitui [args...]
    Launches gitui with the Catppuccin Frappe theme pre-applied.

### hist

    Synopsis:  hist
    Searches shell history with fzf, inserts the selection into the command
    line, and copies it to the clipboard via wl-copy.

---

## 5.5 Package Management

### pkg

    Synopsis:  pkg [-h] [-i|-u] <package> [package...]
    Installs or removes packages using the detected system package manager.
    Supports: paru, yay, pacman, apt, dnf, zypper, yum, brew, pkg.

      (no flag)    Auto mode: installs missing packages, removes installed ones
      -i/--install  Force install
      -u/--uninstall  Force uninstall

    pkg firefox             # auto: install if missing, remove if present
    pkg -i ripgrep fd       # force install
    pkg -u cowsay           # force uninstall

    The package-installed check uses the correct query for each PM:
      pacman/paru/yay  pacman -Qi
      apt              dpkg -s
      dnf/zypper/yum   rpm -q
      brew             brew list
      pkg              pkg info

### search

    Synopsis:  search [args...]
    Interactive AUR package search and install via paru or yay.
    Arch Linux only.

    search neovim

### upgrade

    Synopsis:  upgrade
    Full system upgrade via paru -Syu --noconfirm or yay -Syu --noconfirm.
    Arch Linux only.

### cleanup

    Synopsis:  cleanup
    Lists and removes orphan packages via pacman, logging their names to
    ~/.removed_orphans. Arch Linux only.

### parur

    Synopsis:  parur
    Opens an fzf picker of all installed packages (with pacman -Qi previews),
    then removes the selected packages via paru or yay. Arch Linux only.

    parur

---

## 5.6 Dependency Management

### fish-deps

    Synopsis:  fish-deps [status|install|update|sync]
    Unified command for managing all tools this configuration depends on.

      status   (default) Show installed/missing status grouped by tier
      install  Interactively install each missing dependency
      update   Update all installed dependencies
      sync     Install missing deps, then update all

    Install method priority (highest to lowest):
      1. git+cargo source build (fish shell itself)
      2. cargo (Rust tools — gets latest crate version)
      3. system PM (paru/apt/brew/etc.)
      4. git clone (fzf)
      5. curl installer (starship, fisher, uv)

    When multiple methods are available you are prompted to choose.

    Dependencies are grouped into three tiers:

      Required      fish, fzf, zoxide
      Integrations  wakatime, tailscale
      Recommended   cargo, starship, uv, direnv, paru, yay, eza, lsd, bat,
                    btop, dust, duf, prettyping, ov, ripgrep, lazygit,
                    lazydocker, trash, kitty, wezterm, python3

    fish-deps
    fish-deps install
    fish-deps update
    fish-deps sync

### check_fish_deps

    Synopsis:  check_fish_deps
    Backwards-compatibility alias for `fish-deps status`.

---

## 5.7 System and Monitoring

### top

    Synopsis:  top [args...]
    Launches btop as a modern resource monitor. Falls back to system top.

### swapstat

    Synopsis:  swapstat
    Displays a colorized memory report: kernel swappiness, zRAM compression
    ratio, zRAM device details, and active swap priorities.

### sbver

    Synopsis:  sbver [--brief]
    Verifies Secure Boot signatures on all EFI binaries tracked by sbctl.
    Color-codes results: green checkmark (verified), red X (unsigned).
    Prints a pass/fail summary.

      --brief  Suppress per-file output, show only the summary

    sbver
    sbver --brief

### ports

    Synopsis:  ports
    Lists active TCP listeners with lsof, showing port/address without
    hostname resolution.

### screensleep

    Synopsis:  screensleep
    Turns off the display via KDE PowerDevil's "Turn Off Screen" action,
    invoked through busctl.

### lock

    Synopsis:  lock
    Locks the current desktop session using loginctl lock-session.

### sudo-toggle

    Synopsis:  sudo-toggle
    Toggles the sudo NOPASSWD rule on/off via /etc/sudoers.d/nofail-toggle.
    Useful for automated tasks that would otherwise require password entry.

### limine-edit

    Synopsis:  limine-edit
    Opens /boot/limine.conf in sudoedit, then automatically re-enrolls the
    config hash, runs CachyOS boot hooks, and re-signs Secure Boot files.
    Combines the edit and sign steps into a single command.

---

## 5.8 Terminal Management

### tab

    Synopsis:  tab [args...]
    Opens a new tab in Kitty (kitty @ launch --type=tab), WezTerm
    (wezterm cli spawn), or Konsole. Uses current working directory,
    or $cdto if set.

    tab

### split

    Synopsis:  split [-h|-v] [command...]
    Opens a new pane in Kitty or WezTerm, optionally running a command.

      -h/--horizontal  (default) Split below
      -v/--vertical    Split to the right

    split
    split -v nvim README.md

### spwin

    Synopsis:  spwin [args...]
    Spawns a new terminal OS window in Kitty (via spawn-window.sh or
    kitty @ launch --type=os-window) or WezTerm (wezterm cli spawn --new-window).

### detach

    Synopsis:  detach [-h] [--version] <command> [args...]
    Runs a command fully detached via nohup with stdout/stderr discarded.
    The command survives the current session.

    detach rsync -a ./data remote:/backup/

### bkg

    Synopsis:  bkg <command> [args...]
    Launches a command in the background via nohup with output discarded.
    Simpler than detach; no version flag.

    bkg firefox

### ssh

    Synopsis:  ssh [args...]
    In Kitty, wraps ssh with kitten ssh for better terminal integration
    (multiplexing, copy/paste support). Falls back to system ssh elsewhere.

    ssh user@host

---

## 5.9 Clipboard

### y

    Synopsis:  y [text...]
    Copies text to the clipboard via wl-copy (Wayland) or xclip (X11).
    Reads from stdin if no arguments given.

    y "hello world"
    ls | y
    cat file.txt | y

### p

    Synopsis:  p [args...]
    Outputs clipboard contents to stdout.

    p | grep foo
    p > file.txt

### paste

    Alias for p. Identical behaviour.

---

## 5.10 Network

### gip

    Synopsis:  gip
    Fetches and prints both the public IPv4 and IPv6 address via
    icanhazip.com.

### gip4

    Synopsis:  gip4
    Fetches and prints the public IPv4 address.

### gip6

    Synopsis:  gip6
    Fetches and prints the public IPv6 address. Returns 1 if IPv6 is
    unavailable.

### ping

    Synopsis:  ping [args...]
    Wraps prettyping with --nolegend. Pass --legend to show the legend.
    Falls back to system ping.

    ping google.com

### qr

    Synopsis:  qr [text...]
    Generates a UTF-8 QR code from text or stdin. Uses qrencode locally;
    falls back to the qrenco.de API.

    qr "https://example.com"
    echo "https://example.com" | qr

---

## 5.11 Pager and Logging

### logs

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

### smart_exit

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

## 5.12 AI and Developer Tools

### agy

    Synopsis:  agy [args...]
    Wrapper for the agy Antigravity AI CLI. Before launching, delegates to
    agents-init --agents to ensure AGENTS/ is scaffolded and CLAUDE.md is
    symlinked to AGENTS/AGENTS.md in the current project, then forwards all
    arguments verbatim to the real agy binary. Command shadow (C1): when
    __fish_config_op_aliases (or the master) is disabled, the call is
    passed through to the real agy binary unchanged.

    agy chat
    agy resume

### antigravity-ide

    Synopsis:  antigravity-ide [args...]
    Runs the antigravity-ide editor with warnings filtered.

### agents-init

    Synopsis:  agents-init [--agents | --plugins]
    Scaffold an AGENTS/ sub-repository for tracking agent specs, plans, specs,
    and dev logs. Creates AGENTS/ as a standalone git repo, moves any existing
    AGENTS.md into it, and replaces it with a relative symlink (plus
    CLAUDE.md -> AGENTS/AGENTS.md so Claude Code picks up the shared agent
    instructions). Consolidates plans/ and specs/ directly under AGENTS/
    (merging any legacy docs/plans, docs/superpowers/plans, or old
    AGENTS/plugins/ locations into the canonical AGENTS/<tgt>), creates
    AGENTS/devlogs/, and wires docs/superpowers/{plans,specs} symlinks back to
    them. Adds managed paths to .gitignore and auto-commits every change inside
    the AGENTS/ sub-repo; pulls first when the sub-repo has an upstream.
    Fully idempotent: a second run produces no output and no new commits.
    Flags: --agents re-runs only the AGENTS.md / symlink step; --plugins
    re-runs only the plans/specs/devlogs wiring step. Called automatically by
    the claude and agy wrappers on every invocation.

    Structure versioning: each AGENTS/ repo carries a self-contained version
    bumper. AGENTS/.version holds MAJOR.MINOR.PATCH (seeded 1.0.0). Committed
    git hooks under AGENTS/.agents-tools/ (wired via core.hooksPath) bump it on
    every commit: MINOR (resetting PATCH) when the tracked directory set
    changes, PATCH otherwise; MAJOR is manual-only. A prepare-commit-msg hook
    appends "(vX.Y.Z)" to the commit subject. Downstream tooling can read
    AGENTS/.version - a changed MINOR field signals a structure change. The
    script and hooks are shipped from scripts/agents-tools/ and refreshed when
    their version marker is stale.

    agents-init
    agents-init --agents
    agents-init --plugins

### claude

    Synopsis:  claude [args...]
    Wrapper for the claude CLI. Before launching, delegates to agents-init
    --agents to ensure AGENTS/ is scaffolded and CLAUDE.md is symlinked to
    AGENTS/AGENTS.md in the current project, then forwards all arguments
    verbatim to the real claude binary. Command shadow (C1): when
    __fish_config_op_aliases (or the master) is disabled, the call is
    passed through to the real claude binary unchanged.

    claude
    claude --resume

### claude-docs

    Synopsis:  claude-docs
    Invokes Claude Code to analyze recent repository changes and update
    README.md, ensuring all documented features and examples are accurate.

### claude-pr

    Synopsis:  claude-pr
    Invokes Claude Code to run the full PR workflow: create branch,
    conventional commit, verification, push, and open a PR with a manual
    verification checklist.

### superpowers

    Synopsis:  superpowers [on|off] [-g]
    Enables or disables the Superpowers plugin for Antigravity and Claude
    Code at workspace/project scope (default) or user scope (-g/--global).

    superpowers on
    superpowers off -g

---

## 5.13 Media and Utilities

### dng2avif

    Synopsis:  dng2avif [-i <file>] [-o <file>] [-q <n>] [-s <n>] [input.dng]
    Converts a DNG raw image to a 10-bit HDR AVIF using an ImageMagick,
    ffmpeg, avifenc pipeline with metadata sync via exiftool.

      -i/--input    Input file (or positional arg)
      -o/--output   Output file (default: same name, .avif extension)
      -q/--quality  Quality 0-100 (default 92)
      -s/--speed    Encoding speed 0-10 (default 3)

    dng2avif photo.dng
    dng2avif -q 85 -s 5 -i shot.dng -o out.avif

### steam-dl

    Synopsis:  steam-dl
    Launches Steam under systemd-inhibit, preventing the system from going
    idle or sleeping while a download is in progress.

### spark

    Synopsis:  spark [--min=<n>] [--max=<n>] [numbers...]
    Renders a Unicode sparkline bar chart for a sequence of numbers.
    Reads from stdin if no numbers are given.

    spark 1 1 2 5 14 42
    echo "3 7 2 9 1" | spark

---

## 5.14 Miscellaneous

### config-help

    Synopsis:  config-help [SECTION]
               config-help [SECTION] --html
               config-help [SECTION] --man
               config-help -h | --help

    Opens the offline fish shell configuration manual. Without flags, opens
    the Markdown source in the best available pager (ov > bat > man > less >
    cat). If SECTION is given, jumps to the first heading matching that
    keyword (case-insensitive; checks fish-config.index aliases first).

    Flags:
      --html / -w   Open docs/html/index.html in the default browser.
                    If SECTION is given, opens at the matching anchor.
                    Detects the browser via xdg-mime x-scheme-handler/https,
                    then known binaries, then xdg-open as last resort.
                    Respects $fish_help_browser and $BROWSER.
      --man  / -m   Open docs/fish-config.1 via man -l directly.
                    If SECTION is given, jumps to the nearest match.
      --help / -h   Print usage and navigation key reference.

    config-help keybindings
    config-help pkg
    config-help --html
    config-help pkg --html
    config-help --man
    config-help pkg --man

    Also available as: help config [SECTION] [FLAGS]

### config-update

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

### config-toggle

    Synopsis:  config-toggle [-h]

    Opens an interactive TUI for toggling the six opinionated component
    categories (C1–C6) and the master disable variable without having to
    type or remember variable names. Two scope tabs allow independent
    per-scope configuration:

      Universal — persists across all sessions (set -U)
      Session   — current shell only (set -g)

    Changes apply immediately on each value keypress. Always available
    regardless of the __fish_config_opinionated master state.

    The panel adapts to the terminal width automatically, selecting from
    four layout tiers (with a 6-column buffer on each side before stepping
    up to the next tier) and horizontally centering the box. The panel
    redraws within ~0.3 s of a terminal resize with no keypress required.

      COLUMNS >= 90  →  78-wide panel (most detail)
      COLUMNS >= 86  →  74-wide panel
      COLUMNS >= 82  →  70-wide panel
      COLUMNS  < 82  →  52-wide panel (default)

    Navigation:
      ↑ ↓ / k j   Move cursor
      ← → / h l   Set value: OFF ← DEFAULT → ON (clamped)
      Tab          Switch scope (Universal ↔ Session)
      q / Escape   Exit

    Left/Right (or vim-style h/l) move the highlighted value one step along
    the OFF–DEFAULT–ON scale and stop at the ends. DEFAULT erases the
    variable so the master switch / built-in default applies.

    Flags:
      --help / -h   Show usage.

    config-toggle

### bash

    Synopsis:  bash [args...]
    Switches to bash, with XDG config applied. On exit, $SHELL is reset
    back to fish.

### bd-pull

    Synopsis:  bd-pull <owner/repo>
    Fetches unlinked Gitea issues and creates local Beads entries, updating
    issue titles with the assigned Beads IDs.
    Requires $GITEA_TOKEN and $GITEA_URL to be set.

    bd-pull rootiest/fish-config

### cheat

    Synopsis:  cheat <topic> [args...]
    Displays a colorized cheatsheet using cheat -c, falls back to tldr,
    then man.

    cheat tar
    cheat git

### cffetch / ffetch

    Synopsis:  cffetch [args...]  /  ffetch [args...]
    Clears the screen and displays system information via fastfetch with
    the custom config at ~/.fastfetch.jsonc. Falls back to neofetch.

### dockup

    Synopsis:  dockup [-h] [directory]
    Pulls latest Docker images, restarts services in the given Docker
    Compose project, and prunes dangling images.

    dockup ~/myapp

### joplin

    Synopsis:  joplin [args...]
    Runs the Joplin CLI with Node.js deprecation warnings suppressed.

    joplin ls

### ld

    Synopsis:  ld
    Launches lazydocker targeting the currently active Docker context,
    detected via docker context inspect.

### replay

    Synopsis:  replay <commands>
    Runs Bash commands and replays any resulting changes to environment
    variables, aliases, and the working directory back into the current
    Fish session. Useful for sourcing Bash scripts.

    replay "source ~/.bashrc"
    replay "export FOO=bar"

### kitty-logging

    Synopsis:  kitty-logging [install|uninstall|status|dismiss] [-h]

    Manages the Kitty scrollback watcher that powers C5 logging. Ships a
    canonical, version-marked watcher and installs it into the Kitty config
    directory, wiring it into kitty.conf through a sentinel-marked managed
    block. Commenting out any conflicting watcher line avoids double-capture.

    Commands:
      install    Copy/refresh the watcher and add the managed block
      uninstall  Remove the managed block and the watcher file
      status     Show wiring, installed watcher version, and C5 state
      dismiss    Stop the per-session setup reminder

    Runtime capture stays governed by the C5 .logging_disabled sentinel, so
    disabling __fish_config_op_logging makes the watcher inert without
    uninstalling. Install affects new Kitty windows only.

    Example:
      kitty-logging install
      kitty-logging status

### tmux-clean

    Synopsis:  tmux-clean
    Kills all detached (unattached) tmux sessions, leaving attached ones
    running.

### wake-lock

    Synopsis:  wake-lock <command> [args...]
    Runs a command under systemd-inhibit, preventing the system from going
    idle or sleeping until the command completes.

    wake-lock rsync -avz src/ dest/

---
