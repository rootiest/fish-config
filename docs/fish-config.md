---
title: FISH-CONFIG
section: 7
header: Fish Shell Configuration User Manual
date: June 2026
author: Rootiest
---

# NAME

fish-config - personal fish shell configuration for Fish 4.x with modern CLI tool integration

# SYNOPSIS

    help config [SECTION]

Open this manual in the best available pager. Optionally jump to a section
by keyword:

    help config keybindings
    help config pkg
    help config abbreviations
    help config logs

The `help config` syntax integrates with fish's built-in help command.
The underlying `config-help` function is also available directly.

# DESCRIPTION

A production-grade Fish shell configuration targeting Fish 4.x. It provides:

- Drop-in replacements for common Unix tools (ls, cat, rm, du, ping, less)
- Deep Kitty and WezTerm terminal integration: tab/window/pane management from
  the command line
- Optional session logging: terminal scrollback, tmux/zellij panes, and
  paru/yay output captured to ~/.terminal_history (off by default; see below)
- Automatic Python virtualenv activation on directory change
- Cross-platform package management via pkg and fish-deps
- AI scaffolding helpers for Claude Code and Antigravity
- Catppuccin Mocha color theme throughout

CAUTION: **SESSION LOGGING**  
If enabled, this configuration can silently record terminal output to
`~/.terminal_history`: Kitty scrollback on window close, live tmux pane
streams, zellij pane snapshots on exit, and full paru/yay output. These logs
can contain command output, file contents, and secrets printed to the
terminal. Nothing leaves your machine, but the files persist locally. Logging
is off unless you turn it on.
- Enable all logging with: `set -U __fish_config_op_logging on`
- Prefer a menu? Run the interactive picker: `config-settings`
- Turn it back off with: `set -U __fish_config_op_logging off` (or erase the variable)
- See C5 — Logging and Capture for the full breakdown.

The configuration uses a structured file tree:

    ~/.config/fish/
    ├── config.fish                 Main entry point; sets env vars and PATH
    ├── conf.d/
    │   ├── abbr.fish               All abbreviations
    │   ├── autopair.fish           Auto-pair brackets and quotes
    │   ├── cheat.fish              cheat.sh tab completions
    │   ├── done.fish               Desktop notifications for long commands
    │   ├── first_run.fish          One-time init: Fisher bootstrap, theme
    │   ├── key_bindings.fish       Custom key bindings and Vi mode
    │   ├── logging-events.fish     C5 event handlers; syncs logging state
    │   ├── kitty-watcher-reminder.fish  C5 per-session Kitty watcher reminder
    │   ├── paru-wrapper.fish       Auto-generates paru logging wrapper
    │   ├── puffer.fish             !! / !$ / ./ expansion
    │   ├── tmux-logging.fish       C5 starts tmux pipe-pane capture
    │   ├── zellij-logging.fish     C5 fish_exit handler for zellij
    │   ├── sponge_privacy.fish     Sponge privacy patterns
    │   ├── starship.fish           fish_prompt shell-integration markers
    │   ├── tailscale.fish          Tailscale CLI tab completions
    │   ├── theme.fish              Catppuccin syntax highlight colors
    │   ├── tricks.fish             PATH, bang-bang helpers, bat man pages
    │   ├── wakatime.fish           WakaTime shell hook
    │   ├── yay-wrapper.fish        Auto-generates yay logging wrapper
    │   └── zoxide.fish             Zoxide z/zi integration; overrides cd
    ├── functions/                  Custom functions, one per file
    ├── completions/                Tab completion scripts
    ├── integrations/
    │   └── fzf.fish                FZF Catppuccin theme and key bindings
    ├── scripts/
    │   ├── clean_progress_log.py   Strips typescript animations for clean logs
    │   └── agents-tools/           AGENTS.md scripts and git hooks
    └── docs/                       Offline documentation and man page
        ├── fish-config.md          Primary source manual
        ├── fish-config.1           Compiled man page (auto-generated)
        ├── fish-config.index       Section index for help config
        ├── html/                   Chunked HTML docs (auto-generated)
        └── wiki/                   Markdown wiki (auto-generated)

---

# TABLE OF CONTENTS

    1.  Configuration Variables
    2.  PATH Setup
    3.  Key Bindings
    4.  Abbreviations
        4.1  Editors
        4.2  Navigation and Listing
        4.3  Git
        4.4  Terminal Windows, Tabs, and Panes
        4.5  Chezmoi
        4.6  Docker
        4.7  Systemctl
        4.8  AI Assistants
        4.9  History Expansion
        4.10 Miscellaneous
        4.11 Shell Aliases
    5.  Functions Reference
        5.1  File and Directory
        5.2  Navigation
        5.3  Editors and Viewers
        5.4  Git and Version Control
        5.5  Package Management
        5.6  Dependency Management
        5.7  System and Monitoring
        5.8  Terminal Management
        5.9  Clipboard
        5.10 Network
        5.11 Pager and Logging
        5.12 AI and Developer Tools
        5.13 Media and Utilities
        5.14 Miscellaneous
    6.  Dependency Catalog
    7.  Customization
    8.  Fisher Plugins
    9.  Installation
    10. Personalization
    11. Troubleshooting
        11.1 Uninstalling and Reverting to Backup
        11.2 Fish Version Requirement
        11.3 Enable or Disable Session Logging
        11.4 Change or Disable the Greeting
        11.5 Secrets and Machine-Local Configuration
        11.6 Tool Init Does Nothing (Return Sentinel)
        11.7 Missing Dependencies
        11.8 Vi Mode Keybindings
        11.9 What's with the C1-C6 stuff?
    12. Viewing This Manual

---

# 1. CONFIGURATION VARIABLES

These variables are exported from config.fish on every interactive session.
Override them in local.fish (see Section 10, Personalization).

## Environment Directories (XDG)

| Variable | Value |
|---|---|
| `XDG_CONFIG_HOME` | `~/.config` |
| `XDG_CACHE_HOME` | `~/.cache` |
| `XDG_DATA_HOME` | `~/.local/share` |
| `XDG_STATE_HOME` | `~/.local/state` |

Tools that respect XDG are directed to these paths rather than polluting $HOME.

## Tool Homes (XDG-compliant)

| Variable | Value |
|---|---|
| `CARGO_HOME` | `$XDG_DATA_HOME/cargo` |
| `RUSTUP_HOME` | `$XDG_DATA_HOME/rustup` |
| `GOPATH` | `$XDG_DATA_HOME/go` |
| `BUN_INSTALL` | `$XDG_DATA_HOME/bun` |
| `NPM_CONFIG_PREFIX` | `$XDG_DATA_HOME/npm-global` |
| `GNUPGHOME` | `$XDG_CONFIG_HOME/gnupg` |
| `WAKATIME_HOME` | `$XDG_CONFIG_HOME/wakatime` |

## Editor and Pager

| Variable | Value / Notes |
|---|---|
| `EDITOR` | `nvim` (falls back to `vi` if `nvim` is absent) |
| `VISUAL` | unset by default; set a GUI editor via `local.fish` (the `edit` function falls back to a GUI chain when `VISUAL` is empty) |
| `SUDO_EDITOR` | same as `EDITOR` |
| `PAGER` | `ov` (falls back to `less`) |

## Scrollback History

| Variable | Value / Notes |
|---|---|
| `__fish_scrollback_history_dir` | (unset → `~/.terminal_history`) |
| `__fish_scrollback_history_max_files` | (unset → `100`) |
| `SCROLLBACK_HISTORY_DIR` | `~/.terminal_history` (exported mirror) |
| `SCROLLBACK_HISTORY_MAX_FILES` | `100` (exported mirror) |

The `__fish_scrollback_history_*` universal variables are the fish-style source
of truth — set them via `config-settings` → Paths, or `set -U` directly.
`config.fish` exports the `SCROLLBACK_HISTORY_*` mirrors from them, because the
POSIX wrapper scripts (`paru`/`yay`/`tmux`/`zellij` logging and `_prune_terminal_logs`)
read the exported names from the environment. When the `__fish_` vars are unset,
the documented defaults are exported. `config.fish` deliberately does not create
a global source var, which would shadow the universal and stop live edits from
taking effect.

Scrollback logs accumulate in `SCROLLBACK_HISTORY_DIR` as timestamped files.
When the count exceeds `SCROLLBACK_HISTORY_MAX_FILES` the oldest are pruned
automatically on exit. Use `logs` to browse them interactively.

## Other

| Variable | Value | Notes |
|---|---|---|
| `GPG_TTY` | `$(tty)` | ensures GPG passphrase prompts work |
| `CLAUDE_CODE_NO_FLICKER` | `1` | suppress terminal flicker in Claude Code |
| `CDPATH` | `. ~/projects ~` | |

Opinionated defaults (`CDPATH`, `PAGER`/`MANPAGER`, Vi mode, command shadows,
terminal integrations) can be switched off per category with universal
variables — see Section 7, "Opinionated Components (Minimal Mode)".

## Pager Hierarchy

`$PAGER` is set to `ov` when available, falling back to `less`. The `less` wrapper
function extends this into a full chain so anything that calls `less` directly
also benefits:

`$PAGER` → `ov` → `less` → `more` → `cat`

When `bat` is installed, man pages are rendered with syntax highlighting:

| Variable | Value |
|---|---|
| `MANROFFOPT` | `-c` |
| `MANPAGER` | `sh -c 'col -bx \| bat -l man -p'` |

## Integrations

### Zoxide

`cd`, `z`, and `cdi`/`zi` are all mapped to `zoxide`-backed navigation. Tab completions
for `cd` and `z` blend standard directory entries (CWD and `CDPATH`) with frecency
results so both familiar and frequently-visited paths appear in one list.

### DirEnv

Automatically loads `.envrc` files on directory change. Takes priority over
the auto-venv logic — if a directory is managed by `direnv`, the auto-venv
activation is skipped entirely.

### Auto Python Venv

When entering a directory that contains a `.venv/`, the virtualenv is activated
automatically and deactivated when you leave the project tree.

### WakaTime

Every shell command is reported to WakaTime for time-tracking. Set
`FISH_WAKATIME_DISABLED=1` to disable without removing the plugin.

### Tailscale

Full tab completion for the `tailscale` CLI is provided via `conf.d/tailscale.fish`.

### Done Notifications

Desktop notifications fire when a command takes longer than 10 seconds and
the terminal window is not focused. Configured via fish universal variables:

| Variable | Value |
|---|---|
| `__done_min_cmd_duration` | `10000` ms |
| `__done_notification_urgency_level` | `low` |

### Scrollback History

When running inside Kitty, closing a shell session via `exit` saves a timestamped
scrollback snapshot to `SCROLLBACK_HISTORY_DIR`. Files are named:

`scrollback_YYYY-MM-DD_HH-MM-SS.log`

The `paru` and `yay` wrappers (auto-generated in `~/.local/bin/`) run the command
inside a PTY via `script(1)` so download progress bars are preserved on screen,
then render the captured terminal animation down to a clean static log via
`scripts/clean_progress_log.py` (a small terminal-screen emulator that replays
cursor movements, collapses repainted progress frames to their final state,
and preserves ANSI color). If `python3` is unavailable the wrapper falls back to
dropping only the `script(1)` header/footer. Output is saved to:

- `paru_YYYY-MM-DD_HH-MM-SS.log`
- `yay_YYYY-MM-DD_HH-MM-SS.log`

Before pruning, `_scrollback_prune_junk` silently removes empty files, files
with only a single meaningful line (e.g. bare `[exited]` captures), and Kitty
tab-rename prompt captures. Use `exit --no-log` (or `exit -n`) to skip capture.

---

# 2. PATH SETUP

Directories prepended to PATH in this order (first wins):

| Directory | Purpose |
|---|---|
| `~/.local/bin` | Standard user-local executables |
| `~/Applications` | User-installed standalone apps |
| `~/scripts` | Personal shell scripts |
| `~/bin` | Cargo binaries (appended — lowest priority) |
| `$BUN_INSTALL/bin` | Bun runtime and global packages |
| `$NPM_CONFIG_PREFIX/bin` | Global npm packages |
| `~/.lmstudio/bin` | LM Studio CLI |
| `~/.resend/bin` | Resend CLI |
| `~/.fzf/bin` | `fzf` binary (git-installed) |

Cargo binaries are intentionally appended (lowest priority) to avoid
shadowing system-installed Rust tools.

NOTE: While these directories are merged with your system's existing `$PATH` values, any executables in the prepended directories above will override (shadow) system binaries of the same name.

TIP: This standard PATH setup is gated behind the opinionated component overrides toggle. If you prefer to manage your PATH completely manually, you can disable it by setting `__fish_config_op_overrides` to `0` (or toggle it off in the `config-settings` menu).

---

# 3. KEY BINDINGS

The shell uses Vi key bindings (fish_vi_key_bindings). All custom bindings
are active in Insert, Normal, and Visual modes unless noted.

    Binding         Action
    ─────────────────────────────────────────────────────────────────────
    Ctrl+G          Insert the head of the previous command's last path
                    argument. Equivalent to !$:h in Bash.
                    Example: previous = "cd /usr/local/bin"
                             Ctrl+G inserts "/usr/local"

    Ctrl+F          Interactive history substitution. Type old/new then
                    press Ctrl+F to apply s/old/new/ to the previous
                    command. Equivalent to !!:s/old/new/ in Bash.
                    Example: previous = "echo this is a test"
                             type "this is/that was", press Ctrl+F
                             result = "echo that was a test"

    Ctrl+Alt+U      Strip the first token of the current command line,
                    leaving arguments in place with the cursor at the
                    start. Useful for quickly retyping the command.
                    Example: "mkdir new_folder" -> " new_folder"

    Ctrl+Alt+=      Evaluate the current command line buffer with
                    Qalculate! (qalc) and print the result inline.
                    Requires qalc to be installed.
                    Example: type "150 * 1.08", press Ctrl+Alt+=
                             prints 162

    Ctrl+Enter      Smart execute: runs commands instantly without
                    pressing Enter a second time for certain fast-path
                    commands (speedtest-fast, etc.).

    @@              FZF inline picker. Type @@ anywhere on the command
                    line to open an fzf picker and insert a selection
                    at the cursor position.

## FZF Bindings (bundled from PatrickF1/fzf.fish)

    Ctrl+R          Search command history
    Ctrl+Alt+F      Search git-tracked files
    Ctrl+Alt+L      Search git log
    Ctrl+Alt+S      Search git status
    Ctrl+V          Search shell variables
    Ctrl+Alt+P      Search running processes

---

# 4. ABBREVIATIONS

Abbreviations expand when you press Space or Enter. They are terminal-aware:
some expand differently in Kitty vs WezTerm vs other terminals.

## 4.1 Editors

    n / nv / neovim    nvim
    e                  edit
    se                 sudoedit
    k                  kate
    editt              Open new tab with nvim (terminal-aware)
    cdnv               cd ~/.config/nvim
    cdnvn              cd ~/.config/nvim; nvim

## 4.2 Navigation and Listing

    l                  ls
    lS                 lss       (sort by size)
    lsR                lsr       (sort by time, oldest first)
    lX                 lx        (sort by extension)
    lT                 lt        (tree, depth 2)
    lsT                lstree    (full recursive tree)
    lzd                ld        (lazydocker)
    cdi                zi        (interactive zoxide picker)

## 4.3 Git

    g                  git
    lg                 lazygit
    gitig / git-ignore gi        (generate .gitignore)

## 4.4 Terminal Windows, Tabs, and Panes

These abbreviations control the terminal emulator. Each has a Kitty
variant and a WezTerm variant; the correct one is inserted based on
$TERM or $TERM_PROGRAM.

    :w          New OS window
    :wv         Split pane horizontally (new pane below)
    :wh         Split pane vertically (new pane to the right)
    :wo         Detach current window to its own OS window
    :wot        Move current pane to a new tab
    :t          New tab
    :tl         Set tab title
    :tw         Set window title
    :twk        Rename workspace (WezTerm only)
    :tp         Focus previous tab
    :tn         Focus next tab
    :q          Close current pane/window
    :Q          Close current tab
    :sw         spwin (spawn new OS window)

Quick-navigate shortcuts open windows/tabs/panes with preset working dirs:

    :tgk    New tab at ~/.config/kitty
    :tgn    New tab at ~/.config/nvim
    :tgf    New tab at ~/.config/fish
    :tgh    New tab at ~
    :tgcz   New tab at chezmoi source dir
    :tgcm   New tab at chezmoi source dir
    :tgp    New tab at ~/projects
    :tgr    New tab at / (root)

Prefixes :wg* and :wvg* / :whg* open OS windows or splits to the same
set of dirs, respectively.

Prefixes :cd* open tabs with a quick cd shortcut:

    :cdn    cd ~/.config/nvim
    :cdf    cd ~/.config/fish
    :cdh    cd ~
    :cdcz   cd to chezmoi source
    :cdp    cd ~/projects

Appending n to any :cd* abbreviation also runs nvim after changing dir.

## 4.5 Chezmoi

    cm / cme / cmi / cmap / cmad / cmrm / cmcd /
    cz / cze / czi / czap / czad / czrm / czcd

    cm / cz          chezmoi
    cmcd / czcd      chezmoi cd
    cme / cze        chezmoi edit
    cmad / czad      chezmoi add
    cmap / czap      chezmoi apply
    cmrm / cmf / czrm / czf    chezmoi forget
    cmi / czi        chezmoi init

## 4.6 Docker

    dcl         docker context use default
    dcls        docker context ls
    lzd         ld (lazydocker)

## 4.7 Systemctl

    sc          systemctl
    ssc         sudo systemctl
    scu         systemctl --user
    st          systemctl status
    scs         sudo systemctl start
    scr         sudo systemctl restart
    ssct        sudo systemctl start
    sscs        sudo systemctl stop
    sscr        sudo systemctl restart

## 4.8 AI Assistants

    ag          agy
    ag.         agy .
    v           antigravity-ide
    s           wezterm ssh (WezTerm only)

## 4.9 History Expansion

These are implemented as keybinding helpers, but can also be typed:

    !^          Expand to first argument of previous command
    !*          Expand to all arguments of previous command
    typo_sub    Interactive typo substitution (Ctrl+F)
    bang_string !string expansion
    bang_search !?string search
    bang_minus_n  !-n  (nth-previous command)

## 4.10 Miscellaneous

    /exit       exit
    :q          Close pane (alias for terminal close)
    :Q          Close tab
    sudu        sudo -s
    kt          kitty (Kitty only)
    c           cat
    speedtest-fast  fast-cli
    bl          bd list
    bs          bd sync
    bC          bd create --title
    bsh         bd show
    lb          lazybeads

## 4.11 Shell Aliases

These aliases are defined in conf.d/tricks.fish via alias (which creates Fish
functions). They are active in all interactive sessions.

### Navigation

    ..      cd ..
    ...     cd ../..
    ....    cd ../../..
    .....   cd ../../../..
    ......  cd ../../../../..

### Color Overrides

Force color output for common tools:

    grep    grep --color=auto
    fgrep   fgrep --color=auto
    egrep   egrep --color=auto
    dir     dir --color=auto
    vdir    vdir --color=auto

### Safety Wrappers

Add -i (interactive confirmation) to destructive commands:

    cp      cp -i
    mv      mv -i

### Archives and Networking

    tarnow  tar -acf              Create compressed archive (auto-detects format)
    untar   tar -zxvf             Extract a gzip-compressed archive
    wget    wget -c               Resume interrupted downloads by default
    tb      nc termbin.com 9999   Pipe content to termbin.com for quick sharing

### System Logs

    jctl    journalctl -p 3 -xb   Show priority-3 (error) journal entries
                                    from the current boot

---

# 5. FUNCTIONS REFERENCE

## 5.1 File and Directory

### cat

    Synopsis:  cat [args...]

    Enhanced cat replacement. Wraps bat for files, giving syntax highlighting
    and line numbers; passes directories to ls; falls back to raw cat for
    ANSI-colored log files, and finally to /usr/bin/cat if bat is not
    installed.

    Arguments:
      args...  Files or directories to display

    Example:
    cat README.md
    cat ~/projects/myapp

### copy

    Synopsis:  copy <source> <dest>

    Wrapper for cp that strips trailing slashes from source directories,
    preventing unwanted nested copies when the destination already exists.

    Arguments:
      source  Source file or directory
      dest    Destination path

    Example:
    copy ./mydir/ ~/backup
    copy ./mydir/ ~/backup    # copies mydir INTO backup, not backup/mydir/

### du

    Synopsis:  du [--disk|--dir|--dua] [args...]

    Smart disk-usage dispatcher. Without flags, routes to the most appropriate
    tool by context; explicit flags force one. Falls back to system du when the
    preferred tool is not installed.

    Arguments:
      --disk   Force duf  (disk-level free/used overview)
      --dir    Force dust (per-directory tree breakdown)
      --dua    Force dua  (fast interactive space analyzer)
      args...  Files/directories or flags forwarded to the selected tool

    Example:
    du ~/Downloads
    du --disk

### dusize

    Synopsis:  dusize [dir]

    Shows a human-readable disk usage summary using du -sh. Defaults to the
    current directory if no argument is given.

    Arguments:
      dir  Directory to summarize (defaults to current directory)

    Example:
    dusize ~/Downloads
    dusize ~/Videos

### lD

    Synopsis:  lD [args...]

    Lists only directories in long format with icons and hyperlinks. Uses eza,
    falls back to lsd, then to system ls.

    Arguments:
      args...  Arguments forwarded to the listing command

    Example:
    lD ~/projects

### ls

    Synopsis:  ls [args...]

    Lists all files in long format with icons and hyperlinks. Uses eza,
    falls back to lsd, then to system ls.

    Arguments:
      args...  Arguments forwarded to the listing command

    Example:
    ls ~/projects
    ls
    ls -a ~/projects

### lsr

    Synopsis:  lsr [args...]

    Lists files sorted by modification time in reverse (oldest first), one
    per line with icons. Uses eza, falls back to lsd, then to system ls.

    Arguments:
      args...  Arguments forwarded to the listing command

    Example:
    lsr ~/projects

### lss

    Synopsis:  lss [args...]

    Lists all files sorted by size in long format with gradient color scaling.
    Uses eza, falls back to lsd, then to system ls.

    Arguments:
      args...  Arguments forwarded to the listing command

    Example:
    lss ~/downloads

### lstree

    Synopsis:  lstree [args...]

    Displays a full recursive tree of the current directory with icons.
    Uses eza, falls back to lsd, then to system ls -R.

    Arguments:
      args...  Arguments forwarded to the listing command

    Example:
    lstree ~/projects/myapp

### lt

    Synopsis:  lt [args...]

    Displays a directory tree limited to depth 2 with icons. Uses eza,
    falls back to lsd, then to system ls -R.

    Arguments:
      args...  Arguments forwarded to the listing command

    Example:
    lt ~/projects

### ltr

    Synopsis:  ltr [args...]

    Lists all files sorted by modification time in reverse (oldest first) in
    long format with age-based gradient color scaling. Uses eza, falls back
    to lsd, then to system ls.

    Arguments:
      args...  Arguments forwarded to the listing command

    Example:
    ltr ~/projects

### lx

    Synopsis:  lx [args...]

    Lists all files sorted by file extension in long format with icons. Uses
    eza, falls back to lsd, then to system ls -lX.

    Arguments:
      args...  Arguments forwarded to the listing command

    Example:
    lx ~/projects

### mkcd

    Synopsis:  mkcd [-s | --silent] <dir>

    Creates a directory (including any missing parent directories) and
    immediately changes into it. Prints a tree of created directories by
    default, or suppresses output with -s. Delegates creation to
    _fish_mkdir_p.

    Arguments:
      -h, --help    Show usage help
      -s, --silent  Suppress directory creation output
      <dir>         Directory to create and enter

    Exit Status:
      0  Directory created (or already existed) and entered successfully
      1  Directory creation or cd failed

    Example:
    mkcd ~/projects/myapp
    mkcd ~/projects/newapp/src

### mkdir

    Synopsis:  mkdir [args...]

    Interactive wrapper around mkdir that calls _fish_mkdir_p for each
    directory argument to display created path components. Falls back to
    command mkdir -p when flags (e.g. -m 755) are present, and to plain
    command mkdir in non-interactive contexts.

    Arguments:
      args...  Directories to create, or flags passed through to command mkdir

    Example:
    mkdir ~/projects/myapp/src

### poke

    Synopsis:  poke <file> [file...]

    Creates files using touch, automatically creating any missing parent
    directories via _fish_mkdir_p with tree output.

    Arguments:
      file  One or more file paths to create

    Exit Status:
      0  Files created
      1  No file argument provided

    Example:
    poke ~/projects/new/src/main.fish

### rg

    Synopsis:  rg [args...]

    Wraps ripgrep with --hyperlink-format=kitty when running inside Kitty
    terminal, enabling clickable file links in search results. Falls back
    to plain rg on other terminals.

    Arguments:
      args...  Arguments forwarded to ripgrep

    Example:
    rg "TODO" src/
    rg "fish_greeting" ~/.config/fish/
    rg -l "TODO" ~/projects/myapp

### rm

    Synopsis:  rm [-e [options] | -S | args...]

    Enhanced rm that routes deletions through trash when safe. With no
    arguments, lists current trash contents. -e/--empty empties the trash
    (with optional trash-empty sub-arguments). -S/--secure permanently
    deletes via rm -rf and triggers fstrim. Plain paths and -r/-R are sent
    to trash put; any other flags fall back to system rm.

    Opinionated component (C1): when disabled via __fish_config_op_aliases
    (or the __fish_config_opinionated master), behaves exactly like bare
    command rm — no wrapper, no trash, no trapping.

    Arguments:
      (none)              List current trash contents
      -e, --empty [opts]  Empty the trash; opts forwarded to trash empty
      -S, --secure        Permanently delete targets and run fstrim (irreversible)
      -r, -R, --recursive Forwarded to trash put alongside path arguments
      args...             Files or paths to trash or remove

    Exit Status:
      0  Operation succeeded
      1  trash put failed or file not found

    Notes:
      Falls back to /usr/bin/rm when trash is unavailable.

    Example:
    rm file.txt
    rm -e
    rm -S sensitive_key.pem

### scrub

    Synopsis:  scrub [-a] [-d] [-h]

    Recursively finds and removes OS metadata, editor artifacts, compiler
    garbage, and dev caches from the current directory using fd. Routes
    deletions through the custom rm function, trashy, trash-cli, or system
    rm -rf in that priority order. Aggressive mode adds node_modules, logs,
    IDE directories, and AI tool artifacts.

    Arguments:
      -a, --aggressive  Also purge node_modules, *.log, .cache, .idea, AI artifacts
      -d, --dry-run     Show targets without deleting
      -h, --help        Show usage help

    Exit Status:
      0  Sweep completed (or dry run shown)
      1  fd not found, or unknown argument provided

    Example:
    scrub
    scrub -a
    scrub -d

## 5.2 Navigation

### cdi

    Synopsis:  cdi [query]

    Alias for zi — opens zoxide's interactive directory picker for jumping to
    frequently-visited directories using fzf.

    Arguments:
      query  Optional search term to pre-filter the directory list

    Example:
    cdi myproject

### clone

    Synopsis:  clone [args...]

    Alias for clone-in-kitty that clones a repository into a new Kitty terminal
    window. Only works inside the Kitty terminal.

    Arguments:
      args...  Arguments forwarded to clone-in-kitty (typically a repo URL)

    Exit Status:
      0  Repository cloned
      1  Not running inside Kitty terminal

    Example:
    clone https://github.com/user/repo.git

### clonet

    Synopsis:  clonet [args...]

    Alias for clone-in-kitty --type=tab that clones a repository into a new
    Kitty terminal tab. Only works inside the Kitty terminal.

    Arguments:
      args...  Arguments forwarded to clone-in-kitty (typically a repo URL)

    Exit Status:
      0  Repository cloned
      1  Not running inside Kitty terminal

    Example:
    clonet https://github.com/user/repo.git

## 5.3 Editors and Viewers

### edit

    Synopsis:  edit [-V|-t] [-e EDITOR] [-c] [-x TEXT] [-n] [-v|-s] [FILE...]

    Opens files in a text editor, choosing a terminal or GUI editor and
    resolving a rich chain of fallbacks. With no --visual/--terminal flag the
    mode is auto-detected: interactive terminals get the terminal editor
    ($EDITOR), while detached invocations (desktop shortcuts) get the GUI
    editor ($VISUAL). Clipboard contents and literal strings can be opened as
    throwaway temp files. Editor output is suppressed unless --verbose.

    GUI fallback chain:      zed → antigravity-ide → code → kate → kwrite →
                             gnome-text-editor → gedit
    Terminal fallback chain: nvim → vim → micro → nano → vi

    Arguments:
      FILE...           Files to open (any number)
      -V, --visual      Force the GUI editor ($VISUAL or fallbacks)
      -t, --terminal    Force the terminal editor ($EDITOR or fallbacks)
      -e, --editor=X    Use a specific editor binary X
      -c, --clipboard   Open the clipboard contents (as a temp file)
      -x, --text=STR    Open STR as the contents of a new temp file
      -n, --new         Force a new window/instance (best-effort, where supported)
      -v, --verbose     Print the launch command and let editor output through
      -s, --silent      Suppress all output, including the editor's
      -h, --help        Show this help message

    Exit Status:
      0  Editor launched successfully
      1  Conflicting flags, no editor found, or clipboard read failed

    Example:
    edit notes.txt
    edit --visual ~/.config/fish/config.fish
    edit --terminal --new todo.md
    edit --editor=code --clipboard
    edit --text="hello world"

### fc

    Synopsis:  fc [command_prefix]

    Edits the last shell command -- or the most recent one matching a
    prefix -- in $EDITOR, then executes the result. Bash-style fc
    behaviour. Falls back to vi when $EDITOR is unset, and aborts without
    executing if the buffer is left empty.

    Arguments:
      command_prefix   Search history for the newest command matching this

    Exit Status:
      The edited command's exit status, or a message when history lookup
      found nothing.

    Example:
    fc
    fc git

### less

    Synopsis:  less [args...]

    Pager wrapper that tries $PAGER, then ov, then less, then more, then cat
    as fallbacks in that order.

    Arguments:
      args...  Files or options forwarded to the pager

    Example:
    less /var/log/syslog

### rawfish

    Synopsis:  rawfish [args...]

    Launches a Fish shell with NO_TMUX=1 set, bypassing any tmux
    auto-attach or session management hooks.

    Arguments:
      args...  Arguments forwarded to fish

    Example:
    rawfish

### view

    Synopsis:  view [args...]

    Opens files in nvim read-only mode (-R). Falls back to less if nvim
    is not installed.

    Arguments:
      args...  Files or options forwarded to nvim -R or less

    Example:
    view /etc/fstab

## 5.4 Git and Version Control

### auto-pull

    Synopsis:  auto-pull [list]
               auto-pull add [PATH]
               auto-pull remove <NAME|PATH>
               auto-pull status

    Manages the auto-pull registry: the list of repositories that are
    background fast-forwarded when you enter them (see conf.d/auto-pull.fish
    and _auto_pull_sync). The fish-config repo is always covered as a baseline
    and does not need to be added. The registry is a plain text file, one
    absolute git-toplevel path per line, stored machine-locally at
    $__fish_user_dots_path/auto-pull.list (defaults to
    ~/.config/.user-dots/fish/auto-pull.list) and never committed.

    Registry management works regardless of the C2 auto-execution guard; only
    the background sync itself is gated by __fish_config_op_autoexec.

    Arguments:
      list               Show registered repos (default when no subcommand given)
      add [PATH]         Register PATH's git root; defaults to the current repo
      remove <NAME|PATH> Unregister by basename or exact path
      status             Show enabled/disabled state, repo count, and registry path
      -h, --help         Show this help message

    Exit Status:
      0  Subcommand succeeded
      1  Bad usage, target is not a git repo, or target not registered

    Example:
    cd ~/src/qmk_firmware; and auto-pull add
    auto-pull add ~/work/api
    auto-pull list
    auto-pull remove qmk_firmware

### branch

    Synopsis:  branch <branch_name>

    Switches to a local git branch, creating it if it does not already
    exist. Extra arguments are forwarded to git checkout.

    Arguments:
      branch_name   Branch to switch to or create

    Exit Status:
      0  Branch checked out or created
      1  Not inside a git work tree

    Example:
    branch feature/new-ui

### gi

    Synopsis:  gi [-h] [-b] [-p] [-s] [-l] [targets...]

    Generates .gitignore content by querying the gitignore.io API. Appends
    results to the repository's .gitignore with MD5-based deduplication —
    patterns already present are not re-appended — or prints to stdout with
    -s. Supports generic boilerplate and interactive prompt modes.

    Arguments:
      -h, --help         Show help message
      -d, --description  Show the function description
      -l, --list         List all supported targets from the API
      -b, --boilerplate  Append boilerplate from $GITIGNORE_BOILERPLATE
      -p, --prompt       Prompt for patterns to append
      -s, --stdout       Print API output to stdout instead of .gitignore
      targets            Comma- or space-separated list of language/tool names

    Exit Status:
      0  Patterns appended, or resolved with -s/--stdout or -l/--list
      1  Not in a git repository or API fetch failed

    Returns:
      With -s/--stdout, the fetched .gitignore pattern text, printed to stdout.
      With -l/--list, the supported target list, printed to stdout.

    Example:
    gi python,venv
    gi -b -p
    gi -s node > .gitignore

### git-clean

    Synopsis:  git-clean [-h] [-f]

    Fetches and prunes the remote, fast-forwards the current branch, and
    deletes local branches whose tracking remote has been deleted. Switches to
    main/master automatically if the current branch is orphaned.

    Arguments:
      -h, --help   Show help message
      -f, --force  Force-delete unmerged orphaned branches (git branch -D)

    Exit Status:
      0  Cleanup complete
      1  Argument parsing failed

    Example:
    git-clean --force
    git-clean

### gitui

    Synopsis:  gitui [args...]

    Launches gitui with the Catppuccin Frappe theme (frappe.ron), passing any
    additional arguments through to the gitui command.

    Arguments:
      args...  Arguments forwarded to the gitui command

    Example:
    gitui

### gitup

    Synopsis:  gitup [args...]

    Fetches updates from the remote and shows git status. Extra arguments
    are forwarded to git fetch.

    Arguments:
      args...   Forwarded verbatim to git fetch

    Exit Status:
      0  Fetch and status succeeded
      1  Not inside a git work tree

    Example:
    gitup
    gitup --all

### hist

    Synopsis:  hist

    Searches fish history interactively using fzf, inserts the selected command
    into the command line, and copies it to the clipboard via wl-copy.

    Example:
    hist

## 5.5 Package Management

### cleanup

    Synopsis:  cleanup

    Identifies and removes Arch Linux orphan packages using pacman. Logs
    package names and versions to ~/.removed_orphans before removal.

    Example:
    cleanup

### parur

    Synopsis:  parur

    Presents an fzf picker of all installed packages (via pacman -Qqs) with
    pacman -Qi previews, then removes the selected packages using paru or yay.
    Arch Linux only.

    Exit Status:
      0  Packages removed or none selected
      1  No AUR helper (paru or yay) found

    Example:
    parur

### pkg

    Synopsis:  pkg [-h] [-i|-u] <package> [package...]

    Installs or removes packages using the system's available package manager.
    Supports paru, yay, pacman, apt, dnf, zypper, yum, brew, and pkg.
    In auto mode (no flag), detects whether each package is installed and
    toggles it — installing if absent, removing if present.

    The package-installed check uses the correct query for each manager:

      pacman/paru/yay  pacman -Qi
      apt              dpkg -s
      dnf/zypper/yum   rpm -q
      brew             brew list
      pkg              pkg info

    Arguments:
      -h, --help       Show help message
      -i, --install    Force install mode
      -u, --uninstall  Force uninstall mode
      package          One or more package names to install or remove

    Exit Status:
      0  Operation completed
      1  No supported package manager found, unknown flag, or package operation failed

    Example:
    pkg firefox
    pkg -i ripgrep fd-find
    pkg -u cowsay

### search

    Synopsis:  search [args...]

    Delegates to paru or yay for interactive AUR package search and
    installation. Falls back to yay if paru is not installed. Arch Linux only.

    Arguments:
      args...  Arguments forwarded to paru or yay

    Exit Status:
      0  AUR helper ran successfully
      1  No AUR helper (paru or yay) found

    Example:
    search neovim

### upgrade

    Synopsis:  upgrade

    Runs a full system upgrade via paru or yay with --noconfirm. Falls
    back to yay if paru is not installed. Arch Linux only.

    Exit Status:
      0  Upgrade completed successfully
      1  No AUR helper (paru or yay) found

    Example:
    upgrade

## 5.6 Dependency Management

### check_fish_deps

    Synopsis:  check_fish_deps

    Backwards-compatibility wrapper that delegates to fish-deps status to
    report which fish shell dependencies are installed or missing.

    Example:
    check_fish_deps

### fish-deps

    Synopsis:  fish-deps [status|install|update|sync]

    Unified command for managing all tools this configuration depends on,
    dispatching to subcommand handlers. Defaults to status when no subcommand
    is given.

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
                    lazydocker, trash, kitty, wezterm, python3, yt-dlp

    Arguments:
      status   Report installed/missing deps (default)
      install  Install missing deps interactively
      update   Update all installed deps
      sync     Install missing deps, then update all

    Exit Status:
      0  Subcommand completed
      1  Unknown subcommand

    Example:
    fish-deps sync
    fish-deps
    fish-deps install
    fish-deps update

### fzf-update

    Synopsis:  fzf-update

    Installs or upgrades fzf from git HEAD into ~/.fzf. Pulls the latest
    changes if ~/.fzf already exists, or clones the repository if not.

    Example:
    fzf-update

## 5.7 System and Monitoring

### limine-edit

    Synopsis:  limine-edit

    Opens /boot/limine.conf in sudoedit, then re-enrolls the config hash,
    runs CachyOS boot hooks (limine-mkinitcpio), and re-signs all Secure Boot
    files tracked by sbctl. Combines the edit and sign steps into a single
    command.

    Example:
    limine-edit

### lock

    Synopsis:  lock

    Locks the current desktop session using loginctl lock-session.

    Example:
    lock

### ports

    Synopsis:  ports

    Lists all active TCP listeners on the system using lsof, showing
    port numbers and addresses without hostname resolution.

    Example:
    ports

### sbver

    Synopsis:  sbver [--brief]

    Verifies Secure Boot signatures on all EFI binaries tracked by sbctl,
    filtering out "invalid PE header" noise. Color-codes each file as
    verified (green ✓) or unsigned (red ✗) and prints a final summary
    count.

    Arguments:
      --brief  Suppress per-file output; show only the final summary

    Exit Status:
      0  All binaries verified (or summary shown)
      1  sbctl is not installed

    Example:
    sbver
    sbver --brief

### screensleep

    Synopsis:  screensleep

    Turns off the display after a 1-second delay by invoking the KDE
    PowerDevil "Turn Off Screen" global shortcut via busctl.

    Example:
    screensleep

### sudo-toggle

    Synopsis:  sudo-toggle

    Toggles the sudo NOPASSWD rule on and off via
    /etc/sudoers.d/nofail-toggle. Useful for automated tasks that would
    otherwise require a password entry. Clears the sudo credential cache
    when re-enabling, so the lockdown takes effect immediately.

    Exit Status:
      0  Rule toggled

    Example:
    sudo-toggle

### swapstat

    Synopsis:  swapstat

    Displays a colorized memory report showing kernel swappiness,
    zRAM compression ratio, zRAM device details (via zramctl), and
    active swap priority (via swapon).

    Example:
    swapstat

### top

    Synopsis:  top [args...]

    Wraps btop as a modern replacement for top. Falls back to system top
    if btop is not installed.

    Arguments:
      args...  Arguments forwarded to btop or system top

    Example:
    top

## 5.8 Terminal Management

### bkg

    Synopsis:  bkg <command> [args...]

    Launches a command in the background, fully detached from the terminal
    using nohup. All stdout and stderr output is discarded. Simpler than
    detach; no --version flag.

    Arguments:
      command  The command to run detached
      args...  Additional arguments for the command

    Exit Status:
      0  Command launched successfully
      1  No command provided

    Example:
    bkg firefox

### detach

    Synopsis:  detach [-h] [--version] <command> [args...]

    Runs a command in the background using nohup, fully detached from the
    terminal with stdout/stderr discarded. The command survives the current
    session.

    Arguments:
      -h, --help   Show help message
      --version    Show version information
      command      The command to run detached
      args...      Additional arguments for the command

    Exit Status:
      0  Command launched or help/version shown
      1  No command provided or unknown option

    Example:
    detach rsync -a ./data remote:/backup/

### fish_mode_prompt

    Synopsis:  fish_mode_prompt

    Empty override. Suppresses fish's built-in vi-mode prefix ([N]/[I]/etc.)
    that would prepend to the prompt line and break the two-line nim layout.
    Vi-mode display is handled inside fish_prompt itself.

    Exit Status:
      0  Always (function body is empty)

    Example:
    # Rendered automatically by fish; not called directly.

### fish_prompt

    Synopsis:  fish_prompt

    Catppuccin Mocha fallback prompt (nim-style, two-line). Active whenever
    the starship prompt is not available — either starship is not installed or
    C3 overrides are disabled. Has no external dependencies; uses only fish-provided functions
    (set_color, fish_git_prompt, prompt_pwd, prompt_hostname).

    Exit Status:
      0  Always

    Returns:
      The rendered two-line prompt, printed to stdout

    Example:
    # Rendered automatically by fish; not called directly.

### fish_right_prompt

    Synopsis:  fish_right_prompt

    Renders the right-side prompt. Always shows a dim timestamp. When the last
    command failed, prefixes it with a red ✘ and the exit code. When starship
    is installed and C3 overrides are enabled, also shows the active Docker
    context (if non-default) — that block is paired with the starship prompt
    which already guards on both conditions.

    Exit Status:
      0  Always

    Example:
    # Rendered automatically by fish; not called directly.

### split

    Synopsis:  split [-h | -v] [command...]

    Opens a new pane split in Kitty or WezTerm, optionally running a
    command in it. Defaults to a horizontal (bottom) split. The new pane
    inherits the current working directory.

    Arguments:
      -h, --horizontal  Open a horizontal split (default)
      -v, --vertical    Open a vertical split
      command...        Command to run in the new pane; opens a bare fish
                        shell if omitted

    Exit Status:
      0  Pane opened successfully
      1  Not running inside Kitty or WezTerm

    Example:
    split
    split -v nvim README.md

### spwin

    Synopsis:  spwin [args...]

    Spawns a new terminal OS window in Kitty (via spawn-window.sh if
    present, otherwise kitty @ launch) or WezTerm (via wezterm cli spawn).

    Arguments:
      args...  Arguments forwarded to the spawn command

    Exit Status:
      0  Window opened successfully
      1  Not running inside Kitty or WezTerm

    Example:
    spwin

### ssh

    Synopsis:  ssh [args...]

    Wraps ssh with kitten ssh inside Kitty terminal for better terminal
    integration (terminfo forwarding, multiplexing, copy/paste support).
    Falls back to system ssh on
    other terminals.

    Arguments:
      args...  Arguments forwarded to kitten ssh or system ssh

    Example:
    ssh user@host

### tab

    Synopsis:  tab [args...]

    Opens a new tab in Kitty, WezTerm, or Konsole using the current
    working directory (or $cdto if set). Arguments are forwarded to the
    terminal's tab-open command.

    Arguments:
      args...  Arguments forwarded to the terminal's launch command

    Exit Status:
      0  Tab opened successfully
      1  No supported terminal found

    Example:
    tab

## 5.9 Clipboard

### p

    Synopsis:  p [args...]

    Outputs clipboard contents to stdout. Uses wl-paste on Wayland,
    falls back to xclip on X11. Supports -h/--help for usage info.

    Arguments:
      -h, --help  Show usage help
      args...     Arguments forwarded to the clipboard tool

    Exit Status:
      0  Clipboard contents read successfully
      1  No supported clipboard tool found

    Returns:
      The clipboard contents, printed to stdout

    Example:
    p | grep foo
    p > file.txt

### paste

    Synopsis:  paste [args...]

    Outputs clipboard contents to stdout. Uses wl-paste on Wayland,
    falls back to xclip on X11.

    Arguments:
      args...  Arguments forwarded to the clipboard tool

    Exit Status:
      0  Clipboard contents read successfully
      1  No supported clipboard tool found

    Returns:
      The clipboard contents, printed to stdout

    Example:
    paste > file.txt

### y

    Synopsis:  y [text...]

    Copies text to the system clipboard using wl-copy (Wayland) or xclip (X11).
    Reads from stdin when no arguments are given.

    Arguments:
      text  Text to copy; reads from stdin if omitted

    Exit Status:
      0  Text copied to clipboard
      1  No clipboard provider found

    Example:
    y "hello world"
    ls | y
    cat file.txt | y

## 5.10 Network

### fast

    Synopsis:  fast

    Displays a styled message indicating that the fast command is unavailable
    and suggests using fast-cli instead.

    Example:
    fast

### fast-cli

    Synopsis:  fast-cli [args...]

    Runs a network speed test using the fast.com CLI tool.

    Arguments:
      args...  Arguments forwarded to the fast command

    Example:
    fast-cli

### gip

    Synopsis:  gip

    Fetches and prints both the public IPv4 and IPv6 addresses using
    icanhazip.com. Shows "Not detected" for any address that times out.

    Example:
    gip

### gip4

    Synopsis:  gip4

    Fetches and prints the machine's public IPv4 address using icanhazip.com.

    Example:
    gip4

### gip6

    Synopsis:  gip6

    Fetches and prints the machine's public IPv6 address using icanhazip.com.
    Prints an error message if IPv6 is unavailable on the current network.

    Exit Status:
      0  IPv6 address resolved
      1  IPv6 unavailable or not supported on this network

    Returns:
      The machine's public IPv6 address, printed to stdout

    Example:
    gip6

### ping

    Synopsis:  ping [args...]

    Wraps prettyping with --nolegend by default for a cleaner display.
    Pass --legend to show the legend. Falls back to system ping if
    prettyping is not installed.

    Arguments:
      --legend  Show the prettyping legend (overrides default --nolegend)
      args...   Arguments forwarded to prettyping or system ping

    Example:
    ping google.com
    ping --legend google.com

### qr

    Synopsis:  qr [text...]

    Generates a UTF-8 QR code from the given text or from stdin if no
    argument is provided. Uses qrencode locally if available, otherwise
    falls back to the qrenco.de API via curl.

    Arguments:
      text...  Text to encode; reads from stdin if omitted

    Example:
    qr "https://example.com"
    echo "hello" | qr

## 5.11 Pager and Logging

### logs

    Synopsis:  logs [-h] [-c <category>]

    Interactively browses terminal log files (scrollback, paru, yay) sorted
    newest-first using fzf. Supports viewing in $PAGER, editing, and deletion.

    Keybindings inside the fzf browser:
      Enter    Open in $PAGER
      Ctrl+E   Open in $EDITOR
      Ctrl+D   Delete (with confirmation)
      ?        Toggle keybind help overlay

    Paru and yay logs open in ov with syntax highlighting and sticky section
    headers. Scrollback logs open in ov with per-command sticky prompt headers
    based on OSC 133 markers.

    Arguments:
      -h, --help           Show help message
      -c, --category cat   Filter to one category: scrollback, paru, or yay

    Exit Status:
      0  File viewed or no file selected
      1  No log files found

    Example:
    logs -c paru
    logs
    logs -c scrollback

### smart_exit

    Synopsis:  smart_exit [-h] [-n]

    Closes the shell session. In Kitty, captures the terminal scrollback to a
    timestamped log file in $SCROLLBACK_HISTORY_DIR before exiting.
    Automatically prunes junk and the oldest logs when the count exceeds
    $SCROLLBACK_HISTORY_MAX_FILES.

    Arguments:
      -h, --help    Show help message
      -n, --no-log  Exit without saving a scrollback log

    Exit Status:
      0  Shell session exited
      1  Argument parsing failed

    Notes:
      The exit builtin is wired to smart_exit for interactive sessions. Typing
      `exit` or Ctrl+D behaves identically to calling smart_exit directly.

    Example:
    smart_exit
    smart_exit --no-log

### sponge_filter_secrets

    Synopsis:  sponge_filter_secrets <command> <exit_code> <previously_in_history>

    Custom sponge filter that prevents commands from being stored in history
    when they contain the literal value of any exported environment variable
    whose name indicates it holds a credential (TOKEN, PASSWORD, SECRET,
    API_KEY, etc.).  This catches shell-expansion leakage where a variable
    value is embedded directly in the command string at execution time — a
    case that static regex patterns cannot cover.

    Any variable whose name matches the sensitive-name heuristic and whose
    value is longer than 8 characters (excluding bare paths) is checked.
    The value is escaped for literal regex matching before comparison.

    Arguments:
      command                 The exact command that was entered
      exit_code               Exit code of the command (unused)
      previously_in_history   "true"/"false" flag (unused)

    Exit Status:
      0  Command contains a secret value — filter out of history
      1  No secret value found — keep in history

    Example:
    # Register with sponge (done automatically by conf.d/sponge_privacy.fish):
    set -U -a sponge_filters sponge_filter_secrets

## 5.12 AI and Developer Tools

### agents-init

    Synopsis:  agents-init [-a | --agents] [-p | --plugins] [-v | --verbose]
                           [-q | --quiet] [-s | --silent] [-h | --help]

    Scaffolds an AGENTS/ sub-repository inside a project directory. Creates
    a self-contained git repo for agent specifications, moves any existing
    agent-related files into it, and replaces them with symlinks so the outer
    project never tracks agent files directly.

    File layout after setup:
      AGENTS/AGENTS.md          canonical agent spec (real file)
      AGENTS/CLAUDE.md          real file (if CLAUDE.md existed separately)
                                or symlink → AGENTS.md (single-source case)
      <root>/AGENTS.md          → AGENTS/AGENTS.md
      <root>/CLAUDE.md          → AGENTS/CLAUDE.md
      AGENTS/plans              superpowers plans      (real dir, .gitkeep)
      AGENTS/specs              superpowers specs      (real dir, .gitkeep)
      AGENTS/devlogs            agent development logs (real dir, .gitkeep)
      AGENTS/.version           MAJOR.MINOR.PATCH structure version (seed 1.0.0)
      AGENTS/.agents-tools/     committed version-bump script + git hook shims
      docs/superpowers/plans    → ../../AGENTS/plans   (always)
      docs/superpowers/specs    → ../../AGENTS/specs   (always)
      docs/plans                → ../AGENTS/plans   (only if docs/plans existed)
      docs/specs                → ../AGENTS/specs   (only if docs/specs existed)
      docs/devlogs              → ../AGENTS/devlogs (only if docs/devlogs existed)

    plans/ and specs/ are merged from every legacy location (docs/<tgt>,
    docs/superpowers/<tgt>, and the old AGENTS/plugins/ layout) into the
    canonical AGENTS/<tgt>; the AGENTS/plugins/ layer is removed.

    Each AGENTS repo carries a self-contained version bumper wired via
    core.hooksPath: a pre-commit hook bumps AGENTS/.version on every commit
    (MINOR when the tracked directory set changes, PATCH otherwise; MAJOR is
    manual-only), and a prepare-commit-msg hook appends "(vX.Y.Z)" to the
    commit subject. Each shim then chains (execs) to the global/system
    core.hooksPath hook of the same name, so this local override does not
    shadow global hooks (e.g. ggshield, Git LFS). The script/hooks are
    version-managed from scripts/agents-tools/ and refreshed when their marker
    is stale.

    Downstream tooling can read AGENTS/.version directly — a changed MINOR
    field signals a structure change.

    With no flags, runs both --agents and --plugins setup; --agents re-runs
    only the AGENTS.md / symlink step and --plugins only the plans/specs/
    devlogs wiring step. Managed paths are added to .gitignore. The sub-repo
    is pulled first when it has an upstream, and at the end of every
    invocation any uncommitted changes inside it are auto-committed so
    agent-made edits are captured automatically. Fully idempotent: a second
    run produces no output and no new commits.

    Called automatically by the claude and agy wrappers on every invocation.

    Arguments:
      -a, --agents   Set up AGENTS/ repo + AGENTS.md / CLAUDE.md symlinks only
      -p, --plugins  Set up AGENTS/ repo + plans/specs/devlogs dirs + docs/ symlinks only
      -v, --verbose  Print all per-step output (default)
      -q, --quiet    Print one summary line only if changes were made
      -s, --silent   Suppress all output; errors only (standard UNIX convention)
      -h, --help     Show this help message and exit

    Exit Status:
      0  Setup completed successfully
      1  Fatal error (git init failed, move failed, etc.)

    Example:
    agents-init
    agents-init --agents
    agents-init --plugins
    agents-init --quiet

**Used by:** `agy`, `claude`

### agy

    Synopsis:  agy [ARGS...]

    Wrapper for the agy Antigravity AI CLI that ensures the AGENTS/
    sub-repository is initialized and any agent-made changes are committed
    before launch. Delegates all scaffold and commit logic to agents-init
    --quiet (full setup), which ensures AGENTS/ is scaffolded and CLAUDE.md
    is symlinked to AGENTS/AGENTS.md in the current project. All arguments
    are forwarded verbatim to the real agy binary.

    Opinionated component (C1): when disabled via __fish_config_op_aliases
    (or the __fish_config_opinionated master), the command is passed through
    to the real agy binary unchanged.

    Arguments:
      ARGS  Any arguments forwarded verbatim to the underlying agy binary

    Exit Status:
      Exit status of the underlying agy binary

    Example:
    agy
    agy chat
    agy resume

**Dependencies:** `agents-init`

### antigravity-ide

    Synopsis:  antigravity-ide [args...]

    Wrapper for the antigravity-ide command that filters a known noisy warning
    about an unrecognized 'app' option from stderr.

    Arguments:
      args...  Arguments passed through to the antigravity-ide command

    Example:
    antigravity-ide

### claude

    Synopsis:  claude [ARGS...]

    Wrapper for the claude CLI that ensures the AGENTS/ sub-repository is
    initialized and any agent-made changes are committed before launch.
    Delegates all scaffold and commit logic to agents-init --quiet (full
    setup), which ensures AGENTS/ is scaffolded and CLAUDE.md is symlinked
    to AGENTS/AGENTS.md in the current project.
    All arguments are forwarded verbatim to the real claude binary.

    Opinionated component (C1): when disabled via __fish_config_op_aliases
    (or the __fish_config_opinionated master), the command is passed through
    to the real claude binary unchanged.

    Arguments:
      ARGS  Any arguments forwarded verbatim to the underlying claude binary

    Exit Status:
      Exit status of the underlying claude binary

    Example:
    claude
    claude --resume
    claude "Explain the recent changes"

**Dependencies:** `agents-init`

### claude-docs

    Synopsis:  claude-docs

    Invokes Claude Code to analyze recent repository changes and update
    README.md, ensuring all features and examples are accurate and pruning
    obsolete content.

    Example:
    claude-docs

### claude-pr

    Synopsis:  claude-pr

    Invokes Claude Code to perform a full PR workflow: create a kebab-case
    branch, write a Conventional Commit, run verification, push, and open a
    pull request with a manual verification checklist.

    Example:
    claude-pr

### dops

    Synopsis:  docker [subcommand] [args...]

    Wrapper for docker that intercepts the ps subcommand and redirects it to
    the dops function for enhanced container listing. All other subcommands are
    passed through to the real docker binary.

    Arguments:
      subcommand  Docker subcommand (ps is redirected to dops)
      args...     Arguments forwarded to docker or dops

    Example:
    docker ps

### qc

    Synopsis:  qc [prompt...]

    Quick-chat wrapper around the aichat LLM CLI that defaults to the "cli"
    role — a system prompt tuned for concise, terminal-friendly output.
    Resolves the aichat config directory (honoring $XDG_CONFIG_HOME), creates
    it if missing, and on first use installs the bundled role by symlinking
    scripts/cli-agent.md to $XDG_CONFIG_HOME/aichat/roles/cli.md. Inherits
    every aichat flag and tab completion (--wraps aichat); passing --role/-r
    overrides the default role, so qc forwards to aichat unchanged. The
    function is only defined when aichat is installed. Run `qc --help` for
    aichat's full flag reference with the command name rewritten to qc.

    Arguments:
      prompt...     Prompt forwarded to aichat
      -h, --help    Show usage help

    Exit Status:
      aichat's exit status.

    Example:
    qc "how do I list open ports on linux?"
    qc -m ollama:llama3 "explain this error"
    qc --role coder "refactor this function"

### superpowers

    Synopsis:  superpowers [on|off] [-g]

    Enables or disables the superpowers plugin for both antigravity-cli
    (workspace scope) and Claude (project scope). Use -g/--global to apply
    at the user scope instead of workspace/project.

    Arguments:
      on            Enable superpowers for both tools
      off           Disable superpowers for both tools
      -g, --global  Apply at user/global scope instead of workspace/project
      -h, --help    Show usage help

    Exit Status:
      0  Mode applied successfully
      1  No on/off mode specified

    Example:
    superpowers on
    superpowers off -g

## 5.13 Media and Utilities

### dng2avif

    Synopsis:  dng2avif [-h] [-i <file>] [-o <file>] [-q <n>] [-s <n>] [input.dng]

    Converts a DNG raw image to a 10-bit HDR AVIF using a three-step pipeline:
    develop with ImageMagick, encode with ffmpeg+avifenc, sync metadata with
    exiftool. Requires magick, ffmpeg, avifenc, and exiftool.

    Arguments:
      -i, --input FILE    Input DNG file
      -o, --output FILE   Output AVIF file (defaults to input basename)
      -q, --quality N     Encoding quality 0-100 (default: 92)
      -s, --speed N       Encoder speed 0-10 (default: 3, 0 = slowest)
      -h, --help          Show help message

    Exit Status:
      0  Conversion complete
      1  File not found, missing dependency, or encode step failed

    Example:
    dng2avif photo.dng
    dng2avif -q 85 -s 5 -i shot.dng -o out.avif

### spark

    Synopsis:  spark [--min=<n>] [--max=<n>] [numbers...]

    Renders a Unicode sparkline bar chart for a sequence of numbers.
    Reads numbers from arguments or from stdin if none are provided.
    Optional --min and --max clamp the scale range.

    Arguments:
      --min=<n>   Minimum value for scale (default: list minimum)
      --max=<n>   Maximum value for scale (default: list maximum)
      numbers...  Space-separated numbers to chart; reads stdin if omitted
      -v, --version  Print version
      -h, --help     Show usage help

    Example:
    spark 1 1 2 5 14 42
    seq 64 | sort --random-sort | spark
    echo "3 7 2 9 1" | spark

### steam-dl

    Synopsis:  steam-dl

    Launches Steam with systemd-inhibit to prevent the system from idling
    or sleeping during active downloads.

    Example:
    steam-dl

### yt-dlp

    Synopsis:  yt-dlp [args...] URL [URL...]

    Wraps yt-dlp, injecting sane embedding + SponsorBlock defaults
    (--sponsorblock-remove all, --embed-subs, --embed-metadata,
    --embed-thumbnail). Each default is suppressed if the user already
    passes that flag, its alias, or its negation (e.g. --no-embed-thumbnail
    drops our --embed-thumbnail; --no-sponsorblock or your own
    --sponsorblock-remove drops ours). All other arguments pass through
    untouched. --help and friends fall through to real yt-dlp.

    Opinionated component (C1): when disabled via __fish_config_op_aliases
    (or the __fish_config_opinionated master), passes straight through to
    the system yt-dlp with no defaults injected.

    Arguments:
      args...  Arguments forwarded to yt-dlp (defaults prepended)
      --no-embed-thumbnail  Skip thumbnail embedding for this run

    Example:
    yt-dlp dQw4w9WgXcQ
    yt-dlp --no-embed-thumbnail dQw4w9WgXcQ   # drops our thumbnail default

## 5.14 Miscellaneous

### bash

    Synopsis:  bash [args...]

    Switches the current shell session to bash, loading config from the XDG
    config directory. Resets $SHELL back to fish on exit.

    Arguments:
      args...  Arguments passed through to the bash command

    Example:
    bash

### bd-pull

    Synopsis:  bd-pull <owner/repo>

    Fetches unlinked issues from a Gitea repository, creates corresponding local
    Beads entries, and updates the Gitea issue titles to include the new Bead IDs.
    Requires $GITEA_TOKEN and $GITEA_URL to be set.

    Arguments:
      owner/repo  The repository path in owner/name format

    Exit Status:
      0  Issues linked and synced (or no unlinked issues found)
      1  Missing required argument or environment variables

    Example:
    bd-pull myuser/myproject
    bd-pull rootiest/fish-config

### cffetch

    Synopsis:  cffetch [args...]

    Clears the screen and displays system information using fastfetch with a
    custom config if available. Falls back to neofetch if fastfetch is not installed.

    Arguments:
      args...  Additional arguments forwarded to fastfetch or neofetch

    Example:
    cffetch

### cheat

    Synopsis:  cheat <topic> [args...]

    Displays colorized cheatsheets using cheat -c. Falls back to tldr, then
    man, if cheat is not installed.

    Arguments:
      topic   The command or topic to look up
      args... Additional arguments forwarded to cheat, tldr, or man

    Example:
    cheat tar
    cheat git

### config-help

    Synopsis:  config-help [section]
               config-help --html
               config-help [section] --man
               config-help --help

    Opens the offline fish shell configuration manual in the best available
    pager. Falls back through ov -> bat -> man -> less -> cat.
    If a section keyword is provided, the pager opens at the first heading
    that matches the keyword. Lookup order: docs/fish-config.index (exact
    keyword aliases), then a normalized heading scan as fallback.
    When opened with ov a sticky navigation hint is shown at the top of the
    screen. Section matching is case-insensitive. Pass --html / -w to open
    the published documentation website (https://fish.rootiest.fyi/)
    in the default browser via xdg-open — deep links to a section aren't
    supported there, so if a keyword is given a note points you to the site's
    search box instead. Pass --man / -m to open the compiled man page
    (docs/fish-config.1) via `man -l`; if a section keyword is given, the
    pager opens at the nearest match. Pass --help or -h for usage and the
    navigation key reference.

    Arguments:
      section     Optional keyword to jump to a matching section heading
      -w, --html  Open the published documentation website in the default browser
      -m, --man   Open the compiled man page via man -l
      -h, --help  Print usage and navigation reference, then exit

    Exit Status:
      0  Manual displayed
      1  Documentation file not found, or required tool not available

    Returns:
      With -h/--help, the usage and navigation reference, printed to stdout.
      Otherwise, the manual is shown via the resolved pager (not captured stdout).

    Notes:
      The preferred invocation is `help config [...]` — this function is
      registered as a handler in the help wrapper so that syntax works
      transparently. Direct `config-help` calls are also valid.

    Example:
    config-help
    config-help keybindings
    config-help pkg
    config-help fish-deps
    config-help --html
    config-help --man
    config-help keys --man
    config-help --help
    config-help pkg --man

### config-settings

    Synopsis:  config-settings [-h | --help]

    Opens an interactive full-screen TUI for managing fish config settings
    across four pages, without having to type or remember variable names:

      Universal — opinionated-category toggles (C1–C6) + master, persistent (set -U)
      Session   — the same toggles, current shell only (set -g)
      Sponge    — sponge history-scrubbing settings: delay, successful exit
                  codes, purge-only-on-exit, allow-previously-successful, and
                  extra sensitive variable-name tokens
      Paths     — scrollback log directory, scrollback max files, the user-dots
                  path, and the user-dots convenience symlink toggle (Dots link)

    Toggle rows use ← / → (or h / l) to step OFF ← DEFAULT → ON; DEFAULT erases
    the variable so the master switch / built-in default applies. Value rows
    (Sponge, Paths) use Enter to edit inline; ← / h clears to default. List rows
    (e.g. Extra secret, OK codes) accept values separated by commas and/or
    whitespace — "A, B", "A,B" and "A B" all yield the same two entries.
    Tab / Shift-Tab cycle forward / backward through pages.
    Changes apply immediately — no confirm step. Always available regardless of
    __fish_config_opinionated state.

    The Sponge and Paths pages always write universal variables — these are
    persistent, set-and-forget settings with no per-session scope. Editing a
    scrollback row updates both the __fish_scrollback_history_* source-of-truth
    variables and the exported SCROLLBACK_HISTORY_* mirrors, so the AUR/tmux/
    zellij log wrappers (which read the exported names) see the change in the
    running session.

    The panel adapts to the terminal width automatically, selecting from four
    layout tiers (with a 6-column buffer on each side before stepping up to the
    next tier) and horizontally centering the box. The panel redraws within
    ~0.3 s of a terminal resize with no keypress required.

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

    Arguments:
      -h, --help  Print usage and exit

    Exit Status:
      0  Exited normally (q or Escape pressed)
      1  Unknown flag passed

    Example:
    config-settings

**Used by:** `config-toggle`

### config-toggle

    Synopsis:  config-toggle [args...]

    Deprecated alias for config-settings. Prints a one-line deprecation
    notice to stderr, then delegates all arguments to config-settings.

    Arguments:
      args  Passed through verbatim to config-settings

    Exit Status:
      Same as config-settings

    Example:
    config-toggle        # opens config-settings with a deprecation notice

**Dependencies:** `config-settings`

### config-update

    Synopsis:  config-update [-h | --help] [-f | --force] [-n | --dry-run]

    Pulls the latest fish shell configuration from the upstream repository
    into ~/.config/fish. Git output is suppressed; status is reported
    through colored messages. After a successful pull the function prints a
    short summary of changed files; run `exec fish` to reload the shell.

    Arguments:
      -h, --help      Show this help message and exit
      -f, --force     Stash local changes before pulling, then pop the stash
      -n, --dry-run   Check for upstream changes without applying them

    Exit Status:
      0  Config updated (or already up to date)
      1  Update failed (network error, merge conflict, or not a git repo)

    Example:
    config-update
    config-update --dry-run
    config-update --force

### dockup

    Synopsis:  dockup [-h] [directory]

    Pulls the latest Docker images and restarts all services in a Docker Compose
    project, then prunes dangling images. Accepts an optional target directory.

    Arguments:
      -h, --help   Show help message
      directory    Path to the compose project (defaults to current directory)

    Exit Status:
      0  Services updated and running
      1  Directory not found or no docker-compose.yml present

    Example:
    dockup ~/myapp

### ffetch

    Synopsis:  ffetch [args...]

    Alias for fastfetch that loads a custom config from ~/.fastfetch.jsonc when
    present. Falls back to neofetch if fastfetch is not installed.

    Arguments:
      args...  Arguments forwarded to fastfetch or neofetch

    Example:
    ffetch

### fzf_configure_bindings

    Synopsis:  fzf_configure_bindings [--directory=<key>] [--git_log=<key>] [--git_status=<key>]
                                      [--history=<key>] [--processes=<key>] [--variables=<key>] [-h]

    Installs key bindings for fzf.fish in both insert and default vi modes.
    Each binding can be overridden with a custom key or disabled by passing an
    empty string. Only runs in interactive mode.

    Arguments:
      --directory=key   Override the directory search binding (default: Ctrl-Alt-F)
      --git_log=key     Override the git log search binding (default: Ctrl-Alt-L)
      --git_status=key  Override the git status binding (default: Ctrl-Alt-S)
      --history=key     Override the history search binding (default: Ctrl-R)
      --processes=key   Override the processes search binding (default: Ctrl-Alt-P)
      --variables=key   Override the variables search binding (default: Ctrl-V)
      -h, --help        Show help message

    Exit Status:
      0  Bindings installed or help shown
      22 Invalid option or positional argument provided

    Example:
    fzf_configure_bindings --history=ctrl-h

### joplin

    Synopsis:  joplin [args...]

    Runs the Joplin CLI with Node deprecation warnings suppressed via
    NODE_OPTIONS=--no-deprecation.

    Arguments:
      args...  Arguments forwarded to the joplin command

    Exit Status:
      0  Joplin ran successfully
      1  joplin binary not found in PATH

    Example:
    joplin ls

### kitty-logging

    Synopsis:  kitty-logging [install | uninstall | status | dismiss] [-h]

    Manages the fish-config Kitty scrollback watcher that powers C5 logging.
    `install` symlinks the canonical watcher into the Kitty config dir (so it
    always tracks the source) and wires it into kitty.conf via a
    sentinel-marked managed block, commenting out any conflicting active
    watcher line to avoid double-capture. `uninstall` reverses it. `status`
    reports wiring, installed watcher version, and C5 logging state. `dismiss`
    silences the per-session setup reminder.

    Runtime capture stays governed by the C5 .logging_disabled sentinel, so
    disabling __fish_config_op_logging makes the watcher inert without
    uninstalling. Install affects new Kitty windows only.

    Arguments:
      install    Symlink the watcher and add the managed block to kitty.conf
      uninstall  Remove the managed block and the watcher symlink
      status     Report wiring, watcher version, and C5 logging state
      dismiss    Stop the per-session reminder
      -h, --help Show this help

    Exit Status:
      0  Success
      1  Unknown subcommand/flag, kitty missing, or a write failure

    Example:
    kitty-logging install
    kitty-logging status

### ld

    Synopsis:  ld

    Launches lazydocker targeting the currently active Docker context by
    resolving the host endpoint from docker context inspect.

    Example:
    ld

### open-url

    Synopsis:  open-url [-s|--silent] [-v|--verbose] <url>
               open-url --help

    Opens a URL (or file:// URI) in the best available graphical web browser,
    backgrounded so it never blocks the terminal. Resolves a real browser
    binary rather than deferring to xdg-open, whose MIME dispatch can hand
    local text/html files to non-browser apps (e.g. ebook readers).

    Silent by default: prints nothing on success (errors always go to stderr);
    --silent / -s is accepted for explicitness.

    Resolution order:
      1. $fish_help_browser  (explicit override)
      2. $BROWSER            (validated; errors if not a command)
      3. xdg-mime default handler for x-scheme-handler/https
      4. First known browser binary found in a built-in list
      5. xdg-open            (last resort)

    Arguments:
      url            The URL or file:// URI to open (required)
      -s, --silent   Suppress success output (the default)
      -v, --verbose  Print which browser is being launched
      -h, --help     Print usage and exit

    Exit Status:
      0  Browser launched
      1  No URL given, invalid $BROWSER, or no browser found

    Notes:
      Typo abbreviation: url-open (expands to open-url on space/enter).

    Example:
    open-url https://git.rootiest.dev/rootiest/fish-config
    open-url -v https://fish.rootiest.fyi/

**Used by:** `repo-open`

### replay

    Synopsis:  replay <commands>

    Runs the given commands in Bash and replays any resulting environment
    variable, alias, and directory changes back into the current Fish
    session. Useful for sourcing Bash-only scripts.

    Arguments:
      commands  Bash command string to execute and replay

    Exit Status:
      0  Commands ran successfully and changes were replayed
      1  Bash command exited with a non-zero status

    Example:
    replay "source ~/.bashrc"
    replay "export FOO=bar"

### repo-open

    Synopsis:  repo-open [-p|--print] [-r|--root]
               repo-open --help

    Opens the web page for the current repository's `origin` remote in a
    browser (via open-url). Deep-links to the current branch when it exists
    on the remote, falling back to the remote's default branch (main/master)
    otherwise, and to the current sub-directory when invoked below the repo
    root.

    The remote URL is normalized from both HTTPS and SSH/scp forms
    (git@host:owner/repo.git, ssh://…, https://…). The web path layout is
    provider-specific; the provider is resolved in this order:

      1. git config browse.provider   (per-repo or --global override)
      2. Hostname heuristic           (github / gitlab / gitea / bitbucket;
                                        codeberg → gitea)
      3. Default: github-style layout

    For a self-hosted host the heuristic can't classify (e.g. a Gitea or
    GitLab instance on a custom domain), set the provider once:

      git config browse.provider gitea

    Arguments:
      -p, --print  Print the resolved URL instead of opening it
      -r, --root   Ignore the current sub-directory; link to the repo root
      -h, --help   Print usage and exit

    Exit Status:
      0  URL opened, or resolved with -p/--print
      1  Not a git repo, no origin remote, or browser launch failed

    Returns:
      With -p/--print, the resolved repository URL, printed to stdout

    Notes:
      Typo abbreviation: open-repo (expands to repo-open on space/enter).

    Example:
    repo-open              # open current branch (+ subdir) in browser
    repo-open --print      # just print the URL
    repo-open --root       # repo home page for the current branch

**Dependencies:** `open-url`

### tmux-clean

    Synopsis:  tmux-clean

    Kills all detached (unattached) tmux sessions, leaving any currently
    attached sessions running.

    Example:
    tmux-clean

### wake-lock

    Synopsis:  wake-lock <command> [args...]

    Runs a command under systemd-inhibit to prevent the system from idling
    or sleeping for the duration of the command.

    Arguments:
      command  Command to run with sleep inhibition active
      args...  Arguments forwarded to the command

    Exit Status:
      0  Command ran and completed
      1  No command provided

    Example:
    wake-lock rsync -avz src/ dest/

# 6. DEPENDENCY CATALOG

fish-deps manages these tools. Run `fish-deps` to check status, or
`fish-deps install` to install missing ones.

## Required

| Tool | Description |
|---|---|
| `fish` | Fish shell >= 4.0 |
| `fzf` | Fuzzy finder |
| `zoxide` | Smart cd with frecency |

## Integrations

| Tool | Description |
|---|---|
| `wakatime` | Developer time tracking |
| `tailscale` | Mesh VPN client |

## Recommended

| Tool | Description |
|---|---|
| `cargo` | Rust toolchain (via rustup); used by `fish-deps` to install Rust-based tools and to build fish from source. All paths are gated on `type -q cargo` and degrade gracefully. |
| `starship` | Cross-shell prompt; loaded via `type -q starship` guard. Without it the Catppuccin nim-style fallback prompt activates. |
| `uv` | Python package and project manager (Astral); used by the fish-from-source build path in `fish-deps`. All consumers degrade gracefully without it. |
| `direnv` | Per-directory environment loading; integration is fully guarded with `type -q direnv`. Without it the direnv hook is simply not loaded and auto-venv activates normally. |
| `paru` | AUR helper (Arch only; preferred); guarded throughout — non-Arch systems silently skip AUR-specific paths. |
| `yay` | AUR helper (Arch only; fallback to paru); same guards apply. |
| `eza` | Modern `ls` replacement |
| `lsd` | `ls` replacement (fallback to `eza`) |
| `bat` | Syntax-highlighted `cat` |
| `btop` | Modern resource monitor |
| `dust` | Disk usage tree (Rust) |
| `duf` | Disk usage/free overview |
| `prettyping` | Colorized ping wrapper |
| `ov` | Modern pager (replaces `less`) |
| `ripgrep` | Fast line search |
| `lazygit` | Terminal git UI |
| `lazydocker` | Terminal docker UI |
| `trash` | Safe delete (`trash-cli`) |
| `kitty` | GPU-accelerated terminal (primary) |
| `wezterm` | GPU-accelerated terminal (alternative) |
| `python3` | Standalone interpreter — used by the `paru`/`yay` log cleaner. Note: `uv` does not provide `python3` on PATH, and Arch's base does not include it, so it is listed separately. All consumers degrade gracefully without it. |
| `yt-dlp` | Video/media downloader; backs the `yt-dlp` wrapper function. Optional — the wrapper falls back to the system `yt-dlp` and the rest of the config works without it. |

## Install Methods

The install priority for each tool:

| Method | Packages |
|---|---|
| `cargo` | Rust tools (`eza`, `lsd`, `bat`, `dust`, `ov`, `ripgrep`, `trashy`, `zoxide`, `starship`) — always gets the latest crate version |
| system PM | `paru` / `apt` / `brew` / `dnf` / etc. — for tools without a crate |
| `git clone` | `fzf` — installed from GitHub to `~/.fzf/` |
| `curl` | `starship` installer, `fisher` bootstrap, `uv` installer |

---

# 7. CUSTOMIZATION

This section explains how to adapt the configuration to your specific workflow, including local machine overrides and opinionated component toggles.

## Machine-local Configuration

Place machine-specific settings that should not be committed to git in:

    $__fish_user_dots_path/local.fish

`__fish_user_dots_path` defaults to `~/.config/.user-dots/fish`. Set a
custom location with:

    set -U __fish_user_dots_path /path/to/your/dots/fish

Typical uses: additional PATH entries, local aliases, hostname-specific env
vars, work-specific tool configs.

For convenience, a git-ignored `user-dots` symlink in the fish config
directory tracks `$__fish_user_dots_path` so the overlay can be browsed from
`~/.config/fish/`. It is created if missing and repointed if the path changes.
Opt out by setting `__fish_user_dots_symlink` to a falsy value, or toggling
"Dots link" off on the config-settings Paths page — this stops generation and
removes any existing link. It only ever manages a symlink and never clobbers a
real file or directory at that path.

## Secrets and API Keys

    $__fish_user_dots_path/secrets.fish

Store API tokens, GPG keys, private credentials here. This file is never
committed. It is sourced by local.fish directly, not by config.fish.

`local.fish` is sourced at the end of config.fish on every interactive
session, so it and its companion secrets.fish can override anything set
earlier.

## Overriding Configuration Variables

Any variable set in local.fish after the main config loads takes effect.
Example: to increase the scrollback history limit:

    # in local.fish
    set -gx SCROLLBACK_HISTORY_MAX_FILES 200

## Fish Universal Variables

Some settings (fzf colors, theme) are stored in fish_variables via
`set -U`. These are machine-local and git-ignored. Do not commit
fish_variables.

## Opinionated Components (Minimal Mode)

Every opinionated piece of this config is active by default but can be
switched off through six category opt-out variables, each evaluated via
__fish_variable_check. Set a variable to any falsy value (0, false, no,
off, n) to disable its category; erase it or set a truthy value (1, true,
yes, on, y) to re-enable. Unset means enabled — except for C5 logging, which
is opt-in (see below).

An explicit per-category truthy value takes precedence over the master
switch: setting __fish_config_opinionated=0 disables all unset categories,
but a category with an explicit truthy value remains enabled regardless.

C5 (logging) is the one exception to "unset means enabled". Because it
writes terminal output to disk, it is opt-in: unset means disabled, and the
master switch cannot enable it. Only an explicit truthy value turns logging
on.

    Variable                        Disables
    ────────────────────────────────────────
    __fish_config_op_aliases        Command shadows and flag injection:
                                    ls->eza, cat->bat, cd->zoxide,
                                    rm->trash, less->ov, top->btop,
                                    ping->prettyping, ssh->kitten,
                                    du->duf/dust, mkdir/bash wrappers,
                                    history timestamps, grep/cp/mv/wget
                                    flag injection, help intercept, claude
                                    AGENTS.md auto-link
    __fish_config_op_autoexec       Startup side-effects: Fisher
                                    bootstrap, theme apply, paru/yay
                                    wrapper generation, auto venv
                                    activation, WakaTime hook
    __fish_config_op_overrides      Key and env overrides: Vi mode,
                                    exit->smart_exit, PAGER/MANPAGER,
                                    CDPATH, bang-bang system, autopair,
                                    puffer, starship prompt, theme
                                    colors, FZF_DEFAULT_OPTS, right
                                    prompt
    __fish_config_op_integrations   Terminal/tool coupling: Kitty/
                                    WezTerm window abbreviations, done
                                    notifications, spwin/tab/split,
                                    hist, logs, upgrade, WakaTime
    __fish_config_op_logging        Logging & capture (OPT-IN — this one
                                    is off unless explicitly enabled):
                                    scrollback capture on exit, paru/yay
                                    AUR log wrappers, Kitty watcher
                                    capture; sentinel file coordinates
                                    cross-process state
    __fish_config_op_greeting       Greeting & first-run UI: per-session
                                    fish_greeting override (defines empty
                                    function late in config.fish to
                                    suppress distro greetings such as
                                    CachyOS fastfetch); first-run welcome
                                    banner in conf.d/first_run.fish

Examples:

    # Disable command shadows only (rm becomes plain rm again):
    set -U __fish_config_op_aliases off

    # Turn session logging on (opt-in; off until you do this):
    set -U __fish_config_op_logging on

    # Full minimal mode — disable all six categories at once:
    set -U __fish_config_opinionated 0

    # Re-enable everything (except C5 logging, which stays opt-in):
    set -Ue __fish_config_opinionated

    # Minimal mode but keep the greeting:
    set -U __fish_config_opinionated 0
    set -U __fish_config_op_greeting 1
    # (erase both to go back to full-flavor defaults)

For an interactive alternative to setting these variables by hand, run
config-settings — a full-screen TUI that flips any category (including C5
logging) on or off, per session or universally. See its entry in Section 5.

NOTE:
  - Command shadows (rm, cat, ls, ...) react immediately; conf.d-level components (bindings, prompt, abbreviations, hooks) take effect in new shells.
  - With aliases disabled, rm falls back to bare `command rm` — files are deleted permanently, not trashed.
  - Disabled integration commands (spwin, tab, split, hist, logs, upgrade) print an error naming the variable that disabled them.
  - On CachyOS, the distro fish config's own aliases, history override, and bang-bang bindings are stripped per category as well.

### Component Reference

The following tables detail every component in each category. Use this
reference to understand exactly which behaviors change when you toggle a
category variable.

#### C1 — Command Shadows

Disabling __fish_config_op_aliases restores standard system behavior for
all of these commands.

    Command / Alias    Active behavior                       Disabled fallback
    ───────────────────────────────────────────────────────────────────────────
    ls                 eza -l -a --icons --hyperlink          system ls
    cat                bat syntax-highlighted; dirs → ls      /usr/bin/cat
    cd                 zoxide frecency-based navigation        fish builtin cd
    rm                 moves files to trash (recoverable)     command rm (permanent)
    less               $PAGER → ov → less → more → cat       system less
    du                 duf (disk overview) or dust (dir tree)  system du
    top                btop resource monitor                  system top
    ping               prettyping --nolegend animation        system ping
    ssh                kitten ssh in Kitty terminal           system ssh
    rg                 rg --hyperlink-format=kitty            system rg
    mkdir              verbose path-tree display on creation  mkdir -p silently
    bash               XDG bashrc + $SHELL reset on exit      system bash
    history            timestamps prepended to every entry    fish builtin history
    cp / mv            forced -i confirmation prompt          cp / mv unmodified
    wget               forced --continue (resume downloads)   system wget
    grep/fgrep/egrep   forced --color=auto                    system grep variants
    dir / vdir         forced --color=auto                    system dir / vdir
    help config        intercepts "help config" → config-help  fish builtin help
    claude             auto-links AGENTS.md as CLAUDE.md before launch  command claude
    edit               multi-editor launcher (GUI/term + fallbacks)  $EDITOR/nvim/nano/vi

When C1 is disabled, `rm` uses bare `command rm` with no wrapper — files
are permanently deleted, not trashed. There is no intermediate safety net.

#### C2 — Startup Side-Effects

These run automatically without any user action. Disabling
__fish_config_op_autoexec prevents all of them.

    Component                  Trigger              What it does
    ───────────────────────────────────────────────────────────────────────────
    Fisher bootstrap           First shell only     Downloads and installs fisher
    Fisher update              After bootstrap      Installs all fish_plugins entries
    Catppuccin Mocha theme     First shell only     Applies theme via fish_config
    paru wrapper               Every startup        Writes ~/.local/bin/paru wrapper
    yay wrapper                Every startup        Writes ~/.local/bin/yay wrapper
    Python venv activation     On every cd          Sources .venv/bin/activate.fish
    WakaTime command hook      On every command     Reports to WakaTime API
    Auto-pull fast-forward     On entering a repo   Background ff-only git pull
    user-dots symlink          Every startup        Links $__fish_config_dir/user-dots
                                                    to $__fish_user_dots_path

When C2 is disabled: no Fisher install, no theme application, no paru/yay
wrapper generation, no automatic venv activation, no WakaTime reporting,
no auto-pull (the PWD handler is never registered), and the user-dots
convenience symlink is not created. The symlink is git-ignored and only ever
managed as a symlink — a real file or directory at that path is left untouched.
The symlink has its own opt-out independent of C2: set __fish_user_dots_symlink
to a falsy value (or toggle "Dots link" off on the config-settings Paths page)
to stop generating it and remove any existing link — honoured even when C2 is
enabled. Managed by the __fish_user_dots_link helper.
The first-run completion marker (__fish_config_first_run_complete) is still
set so the init does not re-run on subsequent shells.

Python venv activation fires on every directory change. If a directory uses
direnv (.envrc present), direnv takes priority and auto-venv is skipped for
that directory.

Auto-pull fast-forwards opted-in repositories in the background when you cd
into them. The fish-config repo is always covered; other repos are added with
the `auto-pull` command (see its entry in the functions reference). It only
ever fast-forwards a clean repo whose branch has an upstream — never rebases,
merges, or overwrites work — so it is a no-op on dirty trees, divergent
branches, or repos without a remote. The handler fires once per repo entry
(not on every sub-directory cd). The registry is machine-local at
`$__fish_user_dots_path/auto-pull.list` (defaults to `~/.config/.user-dots/fish/auto-pull.list`) and is never committed.

#### C3 — Key and Environment Overrides

These change fundamental shell behavior: how keys work, which pager opens,
and what the prompt looks like. Disabling __fish_config_op_overrides removes
all of them.

    Override                  What it replaces or sets
    ───────────────────────────────────────────────────────────────────────────
    Vi mode                   fish_vi_key_bindings replaces default Emacs mode
    XDG variables             Sets global XDG Base Directory variables
    PATH setup                Prepends custom bin directories to the PATH
    exit → smart_exit         exit wrapper that captures scrollback before closing
    PAGER=ov                  ov used by git, man, and all $PAGER-aware tools
    MANPAGER=bat pipeline     man pages rendered with syntax highlighting
    CDPATH=. ~/projects ~     bare dir names resolve against ~/projects and ~
    Bang-bang system          ! and $ keys expand history; !^, !*, !-N, !?str?,
                              ^old^new abbreviations; six expand_bang_* helpers
    Autopair                  ( [ { " ' auto-close to (), [], {}, "", ''
    Puffer key intercepts     . ! $ * keys intercepted for smart expansion
    Starship prompt           fish_prompt replaced by Starship + OSC 133 markers
    Catppuccin colors         30+ fish_color_* variables set to Mocha palette
    FZF_DEFAULT_OPTS          FZF themed to Catppuccin Mocha colors
    Right prompt              fish_right_prompt: exit code (on failure) + dim timestamp; always rendered; Docker context added when starship+C3 active

The bang-bang system spans key_bindings.fish, abbr.fish, puffer.fish, and
six expand_bang_*.fish functions. All are gated together — disabling C3
removes the entire bang-expansion system at once.

When C3 is disabled, `exit` falls back to `builtin exit` with no scrollback
capture, no Kitty IPC, and no file I/O on exit. The scrollback capture block
is independently controlled by C5 (see below).

#### C4 — Terminal and Tool Integration

These features couple the shell to specific external tools. Disabling
__fish_config_op_integrations disables all of them.

    Component                  Requires
    ───────────────────────────────────────────────────────────────────────────
    ~60 Kitty/WezTerm abbrs    Active Kitty or WezTerm session
      (:w, :wv, :wh, :t, etc.)
    Done desktop notifications  Graphical desktop with a notification daemon
    spwin                      Kitty or WezTerm
    tab                        Kitty, WezTerm, or Konsole
    split                      Kitty or WezTerm
    hist                       fzf + wl-copy (Wayland clipboard)
    logs                       fzf + ov; reads from ~/.terminal_history/
    upgrade                    paru or yay (Arch Linux only)
    WakaTime hook              wakatime CLI and a configured API key

Disabled integration commands (spwin, tab, split, hist, logs, upgrade) print
a colored error to stderr naming the variable that disabled them rather than
silently failing.

#### C5 — Logging and Capture

Five components capture shell output to disk. Unlike every other category,
C5 is opt-in: it stays off until __fish_config_op_logging is set to an
explicit truthy value, and a truthy master switch does not enable it. While
it is off, all capture is skipped and the logging wrappers are removed.

    # Turn it on (persistently, in every shell):
    set -U __fish_config_op_logging on

    # Turn it back off:
    set -U __fish_config_op_logging off     # or: set -Ue __fish_config_op_logging

    Component               What it captures
    ───────────────────────────────────────────────────────────────────────────
    Scrollback capture      Terminal session output saved to:
                            ~/.terminal_history/scrollback_YYYY-MM-DD_HH-MM-SS.log
    tmux pane capture       Continuous pane stream via pipe-pane, saved to:
                            ~/.terminal_history/tmux_<session>-w<win>-p<pane>_YYYY-MM-DD_HH-MM-SS.log
    zellij pane capture     Pane scrollback snapshot on shell exit, saved to:
                            ~/.terminal_history/zellij_<session>-p<pane>_YYYY-MM-DD_HH-MM-SS.log
    paru wrapper            All paru/AUR output captured to:
                            ~/.terminal_history/paru_YYYY-MM-DD_HH-MM-SS.log
    yay wrapper             All yay/AUR output captured to:
                            ~/.terminal_history/yay_YYYY-MM-DD_HH-MM-SS.log
    Kitty watcher           watcher.py captures scrollback when Kitty closes

NOTE: **Turning off logging does not delete any existing logs.**  
They remain in `$SCROLLBACK_HISTORY_DIR` (defaults to: `~/.terminal_history/`)
until you remove them manually.

The tmux capture starts automatically when fish launches inside any tmux
pane ($TMUX is set). It uses tmux's native pipe-pane to stream all pane
output directly to disk without an intermediate process. Each fish shell
session gets its own log file; a new log is created on each shell start
(including exec fish and new splits). Before each new log, the oldest
tmux_*.log files are pruned (by modification time) to keep the total within
SCROLLBACK_HISTORY_MAX_FILES, matching the paru/yay wrapper behaviour.

The zellij capture works differently: Zellij has no live output-streaming
facility like pipe-pane, so the log is taken as a one-shot snapshot when the
shell exits, via `zellij action dump-screen --full --ansi` (the --ansi flag
preserves color). The dump is captured on the fish process's stdout and
written to the log file by fish itself (not via `--path`, which would make the
zellij server write the file). A fish_exit handler (registered whenever
$ZELLIJ is set) writes the pane's full scrollback and then prunes old
zellij_*.log files the same way. Because the capture happens at exit, toggling
__fish_config_op_logging takes effect on the next exit with no restart or
sentinel coordination needed — the C5 guard is re-checked when the handler
fires.

LIMITATION — zellij capture only fires on a clean shell exit (typing `exit`,
Ctrl-D, or a logout), because that is when the fish_exit handler runs. It does
NOT capture when you close a pane or quit zellij through zellij itself:

  - Closing a pane signals the shell and tears the pane down concurrently, so
    even if the handler runs, `dump-screen` may find the pane buffer already
    gone.
  - Quitting zellij kills the zellij server, and `dump-screen` needs a live
    server to read from — there is nothing left to snapshot.

This is a structural difference from tmux, NOT a bug. tmux streams pane output
to disk continuously via pipe-pane, so whatever was printed is already saved
no matter how the pane dies. Zellij can only snapshot, and the only reliable
snapshot point from the shell is a clean exit. To guarantee a zellij pane is
logged, end the session with `exit` or Ctrl-D rather than zellij's close-pane
or quit actions.

The Kitty watcher is managed by the kitty-logging command: it symlinks the
watcher (fish-config-watcher.py) into the Kitty config directory and wires it
into kitty.conf via a managed block. Inside Kitty, a non-blocking
per-session reminder points first-time users at `kitty-logging install` until
they install or run `kitty-logging dismiss`; the reminder is itself gated on
C5, so it stays silent until you enable logging. Install affects new Kitty
windows only; runtime disable is still handled by the .logging_disabled
sentinel.

Logging coordination via sentinel file

C5 uses a sentinel file to synchronize state between the shell and
out-of-process components (the Kitty watcher and all running shells):

    ~/.config/fish/.logging_disabled

Because C5 is off by default, the sentinel is present on a fresh install —
the startup sync in conf.d/logging-events.fish reconciles it on every shell
start, so it appears without any action on your part.

Disabling __fish_config_op_logging (or leaving it unset):
  1. Creates the sentinel immediately in every open shell.
  2. Removes ~/.local/bin/paru and ~/.local/bin/yay logging wrappers;
     bare /usr/bin/paru and /usr/bin/yay are used instead.
  3. Kitty's watcher.py reads the sentinel on each save attempt and
     skips capture — no Kitty restart required.
  4. smart_exit stops saving scrollback logs.
  5. Stops tmux pipe-pane capture in every open fish shell inside tmux.

Enabling __fish_config_op_logging:
  1. Removes the sentinel in every open shell.
  2. Regenerates paru/yay logging wrappers in ~/.local/bin/.
  3. Kitty watcher resumes capture on the next session exit.
  4. Restarts tmux pipe-pane capture in every open fish shell inside tmux.

Changes propagate to all running shells through an event handler that fires
whenever __fish_config_op_logging changes — no shell restart needed.

Note: C3 and C5 compose independently. C3 controls whether the smart_exit
wrapper is active at all; C5 controls only the scrollback-capture block
inside it. With C3 disabled, exit is plain builtin exit regardless of C5.

#### C6 — Greeting and First-Run UI

    Component                  What it shows
    ───────────────────────────────────────────────────────────────────────────
    First-run welcome banner   One-time message on first interactive session
    fish_greeting override     Empty function defined late in config.fish to
                               suppress distro greetings (e.g. CachyOS sets
                               fish_greeting to fastfetch by default)

When C6 is disabled, no greeting is printed by this config. Any greeting
set by the distro or other configs runs normally — this config simply does
not override it.

## Prompt and Theme

### Starship

The primary prompt is Starship, initialized by conf.d/starship.fish.
Configure it via ~/.config/starship.toml.

conf.d/starship.fish defines a fish_prompt wrapper that only activates when
starship is in PATH. It emits OSC 133;A (prompt start) immediately before
Starship renders and OSC 133;B (input start) immediately after, placing both
markers on the prompt line itself. This allows ov to use them as sticky
section headers when browsing scrollback logs. Without Starship, fish's
built-in prompt handles these markers automatically.

### Catppuccin Fallback Prompt

When Starship is absent or C3 overrides are disabled, a built-in nim-style
two-line prompt activates from functions/fish_prompt.fish. No external
dependencies — fish builtins only.

Layout:

    ┬─[user@host:~/path] (main)
    ╰─>$

Elements:

    user        Yellow (Catppuccin Yellow); red if root
    @host       Blue (local) or Teal (SSH)
    ~/path      prompt_pwd abbreviation (Catppuccin Text)
    (main)      Current git branch in Catppuccin Pink; omitted outside repos
    ─[V:name]   Active Python venv basename; omitted when none
    ─[N/I/R/V]  Vi-mode indicator when vi bindings are active
    ┬─ / ╰─>    Connector lines: Catppuccin Green on success, Red on failure

The right prompt (fish_right_prompt.fish) always renders, regardless of C3
state. On failure it shows a red ✘ and the exit code; on success it shows
only the dim timestamp. When starship is installed and C3 is enabled, the
active Docker context is also shown (if non-default):

    ✘ 1   󰡨 myctx   Fri Jun 12 00:51:21 2026     ← failed, starship+C3 active
    ✘ 1   Fri Jun 12 00:51:21 2026               ← failed, fallback prompt
    Fri Jun 12 00:51:21 2026                     ← success (no ✘)

### FZF

FZF is themed to Catppuccin Mocha via FZF_DEFAULT_OPTS set in
integrations/fzf.fish. The colors applied:

    Background:   #1E1E2E (base)    #313244 (surface0)
    Foreground:   #CDD6F4 (text)
    Highlights:   #F38BA8 (red)     #CBA6F7 (mauve)    #B4BEFE (lavender)

To customize, override FZF_DEFAULT_OPTS in local.fish.

### Catppuccin Mocha Syntax Highlighting

The Catppuccin Mocha theme ships with this config in themes/ and is applied
on first run via `conf.d/first_run.fish`. Colors are stored in fish_variables
(universal). To switch variants, install a different theme from themes/:

    fish_config theme save "Catppuccin Latte"

---

# 8. FISHER PLUGINS

Fisher is bootstrapped automatically on the **first interactive session** via
`conf.d/first_run.fish`. This also applies the Catppuccin Mocha theme and
prints a one-time welcome message (gated by __fish_config_op_greeting; set
it to 0 to suppress). Subsequent sessions skip all first-run logic with zero
overhead.

To re-trigger first-run initialization (e.g., after a fresh install or for
testing), run:

    set -Ue __fish_config_first_run_complete

Then open a new shell.

## Fisher-Managed Plugins

The following plugins are fully managed by Fisher. Their files are installed
into the repo directory by Fisher and are listed in `.gitignore` — do not
commit them. Fisher installs and updates them automatically.

    jorgebucaran/fisher           Plugin manager itself
    meaningful-ooo/sponge         Remove failed commands from history

## Sponge History Filtering

Sponge removes failed commands from history and, via conf.d/sponge_privacy.fish,
also filters privacy-sensitive commands through three layers:

Layer 1 — Static patterns (universal, persistent across sessions):
Commands matching any of these structural signatures are never recorded:

    --password / --token / --passphrase / --api-key flags with values
    Inline env assignments: GITHUB_TOKEN=xxx, MY_API_KEY=abc
    Fish set with sensitive names: set -gx GITHUB_TOKEN xxx
    URLs with embedded credentials: https://user:pass@host
    HTTP Authorization headers: curl -H "Authorization: ..."
    Basic auth flags: curl -u user:pass
    sshpass, docker login -p, openssl -passin/-passout

Layer 2 — Dynamic secret values (session globals, refreshed each login):
On the first prompt, after secrets.fish has loaded, the literal values of
all exported variables whose names suggest credentials (TOKEN, PASSWORD,
SECRET, API_KEY, etc.) are collected, regex-escaped, and added as a
session-scoped overlay.  Because globals shadow universals in Fish, the
combined list is what sponge sees.  Rotating a token takes effect on the
next login automatically.

Layer 3 — Per-command filter (sponge_filter_secrets):
Catches credentials in variables exported after login, such as tokens
sourced from a project .env file mid-session.

To add your own persistent patterns:

    set -U -a sponge_regex_patterns 'your-regex-here'

To mark additional variable NAMES as credential-bearing (so Layer 2 scrubs
their values), add name tokens — via `config-settings` → Sponge, or directly:

    set -U -a __fish_sponge_extra_sensitive ACME_API VAULT_PW

Tokens are folded into the Layer 2 name match case-insensitively as substrings,
so ACME_API also covers ACME_API_KEY. (The match uses `--entire` to return the
full variable name, so partial-name tokens dereference the right value.)

The `config-settings` Sponge page also surfaces sponge's own tuning variables —
sponge_delay, sponge_successful_exit_codes, sponge_purge_only_on_exit, and
sponge_allow_previously_successful — so they can be changed without typing
variable names.

## Bundled Plugin Functionality

The remaining plugin functionality is bundled directly with this config rather
than managed through Fisher. The bundled versions include customizations for
Fish 4.x compatibility and improved behavior that differ from their upstream
releases. Installing them through Fisher would overwrite these customizations.

Bundled components and their upstream origins:

    catppuccin/fish               → themes/ + conf.d/theme.fish
    PatrickF1/fzf.fish            → functions/_fzf_*.fish + conf.d/fzf.fish
    franciscolourenco/done        → conf.d/done.fish
    jorgebucaran/autopair.fish    → functions/_autopair_*.fish + conf.d/autopair.fish
    nickeb96/puffer-fish          → functions/_puffer_fish_*.fish + conf.d/puffer.fish

Do not run `fisher install` for these — it will overwrite the customized
versions. To update their behavior, edit the relevant bundled files directly.

## fish_plugins Manifest

The `fish_plugins` file at the config root:

    jorgebucaran/fisher           Plugin manager itself
    meaningful-ooo/sponge         Remove failed commands from history

To update all Fisher-managed plugins, run `fisher update` or `fish-deps
update` which calls it as its first step.

---

# 9. INSTALLATION

This configuration is managed as a git repository. To deploy on a new machine:

    mv ~/.config/fish ~/.config/fish.bak   # back up any existing config
    git clone https://git.rootiest.dev/rootiest/fish-config.git ~/.config/fish

Then open a new Fish shell. Fisher installs automatically on first launch
and the Catppuccin Mocha theme is applied. All other plugin functionality is
bundled directly with this config and requires no additional installation.

## Return Sentinel

config.fish ends with a return sentinel guard. Any lines appended after it by
a tool's setup command (starship init fish | source, zoxide init fish | source,
etc.) will have no effect. All integrations are managed via conf.d/ files.

If a new tool's shell integration appears to do nothing, check whether its
setup command appended an init line below the sentinel and create a dedicated
`conf.d/<tool>.fish` instead.

## Updating

Pull the latest changes from the upstream repository without needing a
configured git remote:

    config-update              Fetch and apply the latest commits from upstream
    config-update --dry-run    Preview available changes without applying them
    config-update --force      Stash local changes, pull, then restore the stash

All git output is suppressed. Run exec fish after a successful update to reload.

---

# 10. PERSONALIZATION

Sensitive credentials and machine-specific settings are kept out of version
control in a private directory. The path defaults to
`~/.config/.user-dots/fish/` but can be overridden:

    set -U __fish_user_dots_path /path/to/your/dots/fish

Or use the interactive TUI — run `config-settings` and navigate to the
"Dots Path" row (last row). Press Enter to type a new path, or ← / h to
reset to the default.

config.fish sources local.fish from that directory on every interactive
session. local.fish is responsible for sourcing its own secrets.fish:

    $__fish_user_dots_path/
    ├── secrets.fish   API keys, tokens, passwords, personal identifiers
    └── local.fish     Machine-specific paths, env vars, and sourcing secrets

fish_variables (auto-managed by fish) is excluded from this repo via
.gitignore. Do not commit it.

## secrets.fish

Store anything you would not commit to a public repo: API keys, auth tokens,
passwords, and personal identifiers.

    # secrets.fish
    set -gx MY_NAME "Your Name"
    set -gx MY_EMAIL "you@example.com"
    set -gx GPG_RECIPIENT "you@example.com"
    set -gx GITHUB_TOKEN ghp_yourTokenHere
    set -gx OPENAI_API_KEY sk-proj-yourKeyHere
    set -gx GITEA_TOKEN yourGiteaTokenHere
    set -gx GITEA_CHOSEN_LOGIN your.gitea.instance
    set -gx KOPIA_PASSWORD yourKopiaPassword

## local.fish

Store paths and variables specific to one machine — things that would be
wrong on any other system.

    # CDPATH — directories searched by cd
    set -gx CDPATH . /home/youruser/projects /home/youruser

    # Path to your shared .gitignore boilerplate
    set -gx GITIGNORE_BOILERPLATE ~/.config/git/gitignore_boilerplate

    # SSH shortcuts
    abbr -a sshr 'ssh you@your-server.local'
    abbr -a sshw 'ssh you@work-server.example.com'

    # Docker context shortcuts
    abbr -a dcr 'docker context use my-remote-server'
    abbr -a dcw 'docker context use work-server'

local.fish is sourced at the end of config.fish with an existence check so
the public config works cleanly on any machine without the private repo.
local.fish in turn sources secrets.fish when it exists.

---

# 11. TROUBLESHOOTING

This section covers common issues, their solutions, and how to safely revert changes or uninstall the configuration entirely.

## Uninstalling and Reverting to Backup

The installation step backs up any existing config to `~/.config/fish.bak`.
To revert:

    rm -rf ~/.config/fish
    mv ~/.config/fish.bak ~/.config/fish

If no backup exists, remove the directory and let Fish regenerate a default
config on next launch:

    rm -rf ~/.config/fish
    fish -c 'fish_config theme choose "Fish default"'

Clean up files generated outside the config directory:

    rm -f ~/.local/bin/paru ~/.local/bin/yay        # AUR log wrappers
    rm -f ~/.local/share/man/man1/fish-config.1     # man page symlink
    rm -f ~/.config/fish/.logging_disabled           # C5 sentinel

Erase universal variables set by this config:

    for v in (set -Un | string match '__fish_config*')
        set -Ue $v
    end
    for v in __done_min_cmd_duration __done_notification_urgency_level
        set -Ue $v
    end
    for v in (set -Un | string match 'sponge_*')
        set -Ue $v
    end

The `~/.terminal_history/` log directory contains your session logs. Remove
it only if you do not want to keep them.

## Fish Version Requirement

This config requires Fish 4.x or newer. Check your version:

    fish --version

Run `fish-deps` to see a status report — an outdated Fish shows ⚠ with an
upgrade message.

Upgrading Fish by distribution:

    # Arch / AUR
    pacman -S fish          # or paru -S fish

    # Ubuntu / Debian (PPA)
    sudo apt-add-repository ppa:fish-shell/release-4
    sudo apt update && sudo apt install fish

    # Fedora
    sudo dnf install fish

    # macOS
    brew install fish

For other systems or building from source, see https://fishshell.com.

## Enable or Disable Session Logging

Session logging is opt-in: it is off until you turn it on. To enable all
logging and capture (scrollback, tmux/zellij pane logs, AUR helper wrappers,
Kitty watcher):

    set -U __fish_config_op_logging on

Or toggle it interactively: run `config-settings` and flip the Logging row.

Disable it again — either an explicit falsy value or erasing the variable
returns you to the default off state:

    set -U __fish_config_op_logging off
    set -Ue __fish_config_op_logging

This takes effect immediately in all running shells — no restart needed. The
sentinel file, wrapper removal, and pipe-pane teardown happen automatically.

See C5 — Logging and Capture for the full component breakdown.

## Change or Disable the Greeting

This config suppresses the distro greeting (e.g. CachyOS fastfetch) by
default. To let the distro greeting through:

    set -U __fish_config_op_greeting off

To set a custom greeting, define fish_greeting in your local.fish:

    # in $__fish_user_dots_path/local.fish
    function fish_greeting
        echo "Hello, world!"
    end

The first-run welcome banner runs exactly once. To re-trigger it (e.g. for
testing):

    set -Ue __fish_config_first_run_complete

See C6 — Greeting and First-Run UI for details.

## Secrets and Machine-Local Configuration

Machine-specific config goes in `$__fish_user_dots_path/local.fish` (defaults
to `~/.config/.user-dots/fish/local.fish`). Secrets go in `secrets.fish` in
the same directory.

If local.fish is not loading, verify the path:

    echo $__fish_user_dots_path
    test -f "$__fish_user_dots_path/local.fish"; and echo exists; or echo missing

Change the path via variable or TUI:

    set -U __fish_user_dots_path /new/path/to/dots/fish

Or run `config-settings`, navigate to the Paths page, and edit "Dots path".

The `user-dots` convenience symlink in the config directory tracks this path.
Disable it with:

    set -U __fish_user_dots_symlink false

See Personalization for the full `local.fish` / `secrets.fish`
layout.

## Tool Init Does Nothing (Return Sentinel)

Symptom: you ran a tool's setup command (e.g.
`starship init fish >> ~/.config/fish/config.fish`) and nothing changed.

Cause: `config.fish` ends with a `return` guard. Any lines appended after it
are never executed.

Fix: create a dedicated `conf.d/` file instead of appending to `config.fish`:

    # ~/.config/fish/conf.d/mytool.fish
    mytool init fish | source

All existing integrations (starship, zoxide, direnv) already have `conf.d/`
files. See Return Sentinel for background.

## Missing Dependencies

Run `fish-deps` (defaults to `fish-deps status`) to see what is installed
and what is missing. Common symptoms and their missing tools:

    Symptom                                  Missing tool
    ─────────────────────────────────────────────────────
    ls output has no icons or colors         eza (or lsd)
    cd does not remember directories         zoxide
    cat shows no syntax highlighting         bat
    fzf keybindings do nothing               fzf
    Starship prompt not appearing            starship

Install missing dependencies interactively:

    fish-deps install

Or install everything missing and update what is installed:

    fish-deps sync

See Dependency Catalog for the full list grouped by tier
(required, integrations, recommended).

## Vi Mode Keybindings

This config enables Vi mode by default (via C3 overrides), replacing the
standard Emacs-style bindings. If Vi mode interferes with your workflow,
override it in `local.fish` (See Personalization):

    # $__fish_user_dots_path/local.fish
    fish_default_key_bindings

This restores Emacs-style bindings without disabling the rest of C3
(bang-bang, autopair, starship prompt, pager settings, etc.).

To disable the entire C3 category (Vi mode and all other key/environment
overrides):

    set -U __fish_config_op_overrides off

See C3 — Key and Environment Overrides for the full list of
what C3 controls.

## What's with the C1-C6 stuff?

This configuration groups its opinionated behaviors into six categories (C1–C6), allowing you to selectively disable features that conflict with your workflow. Disabling all of them leaves you with a "Minimal Mode" shell that only manages PATH, XDG variables, and your `local.fish` overrides.

    Category   Description
    ──────────────────────────────────────────────────────────────────────────
    C1         Command Shadows (aliases that replace default tools)
    C2         Auto-Exec (background tasks and startup side-effects)
    C3         Key & Env Overrides (Vi mode, PAGER)
    C4         Terminal Integrations (Kitty, WezTerm)
    C5         Logging and Capture (session logs, command duration)
    C6         Greeting & First-Run UI (custom startup banner)

Disable all opinionated features at once (Minimal Mode):

    set -U __fish_config_opinionated 0

Disable a single category:

    set -U __fish_config_op_aliases off         # C1
    set -U __fish_config_op_autoexec off        # C2
    set -U __fish_config_op_overrides off       # C3
    set -U __fish_config_op_integrations off    # C4
    set -U __fish_config_op_logging off         # C5 (already off by default)
    set -U __fish_config_op_greeting off        # C6

Keep one category active under a master disable:

    set -U __fish_config_opinionated 0
    set -U __fish_config_op_aliases 1           # only C1 stays on

Re-enable everything:

    set -Ue __fish_config_opinionated

For an interactive alternative to setting these variables by hand, run `config-settings`.

---

# 12. VIEWING THIS MANUAL

There are four ways to read this manual.

## The documentation website

    help config --html

Opens https://fish.rootiest.fyi/ in the default browser — the
Starlight-powered site built from `docs/manual/**` on every push to `main`.
It has a section sidebar and full-text search. Deep links to a specific
section aren't supported from the command line; once the site opens, use
its search box to jump straight to what you need.

## As a man page

    help config --man
    help config pkg --man

Opens the compiled docs/fish-config.1 directly via man -l, bypassing
the pager fallback chain. If a section keyword is given, the pager opens
at the nearest matching heading. The symlink is created once on first
run (like an install step) and MANPATH is set each session, enabling
the standard invocation:

    man fish-config

NOTE: fish-config (hyphen) is this config's man page. fish_config
(underscore) is fish's built-in browser-based configuration tool —
a completely separate command. Do not mix them up.

## In the terminal

    help config
    help config keybindings

Without a pager available beyond the basics, `help config [SECTION]` opens
the Markdown manual in the best available viewer, falling back through:

    1. ov + bat   section navigation + syntax highlighting (best)
    2. ov alone   section navigation, raw Markdown
    3. bat alone  syntax highlighting, use / to search
    4. man -l     pre-compiled man page (if available)
    5. less       plain text with line-jump
    6. cat        plain output

With ov, the Markdown renders with syntax highlighting and section-based
navigation:

    Space       next section
    ^           previous section
    Alt+u       toggle section list sidebar
    /           search forward
    n / N       next / previous search match
    g           go to line number
    j           interactive jump target (line, %, or 'section')
    q           quit

If SECTION is given, the pager opens at the first heading that matches the
keyword (case-insensitive; checks `docs/fish-config.index` aliases first,
then falls back to a normalized heading scan):

    help config keybindings
    help config abbreviations
    help config pkg
    help config logs
    help config fish-deps

## Reading the source directly

`docs/manual/**` is the single source of truth this manual, the man page,
and the website are all generated from. Numbered files and directories
correspond to the numbered sections in this manual — browse them in any
editor, or from a shell:

    cd ~/.config/fish/docs/manual
    grep -rn "keybindings" .

Section 5 is the exception. Function entries are generated from the
man-page-style comment header above each function in `functions/*.fish`,
so the documentation for a command lives beside the code that implements
it and cannot drift from it. To read the source for a single function, or
to correct its documentation, open the function itself:

    functions/git-clean.fish

The files under `docs/manual/05-functions/` carry only the category
titles, ordering, and search keywords.
