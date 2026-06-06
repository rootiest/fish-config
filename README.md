# Fish Shell Configuration

A feature-rich Fish shell configuration for CachyOS (Arch Linux), built around a Catppuccin Mocha aesthetic with a curated set of modern CLI tool integrations, smart shell functions, and a heavily customized abbreviation system for keyboard-driven workflows.

## Table of Contents

- [Overview](#overview)
- [Structure](#structure)
- [Plugins](#plugins)
- [Theme & Prompt](#theme--prompt)
- [Integrations](#integrations)
- [Key Bindings](#key-bindings)
- [Functions](#functions)
- [Abbreviations](#abbreviations)
- [Dependencies](#dependencies)
- [Installation](#installation)
- [Personalization](#personalization)
- [Attribution](#attribution)
- [License](#license)

---

## Overview

This config layers on top of the CachyOS base Fish configuration and adds:

- **Catppuccin Mocha** theming throughout (prompt, FZF, Zellij)
- **Starship** prompt with VI key bindings
- **Fisher** plugin management with FZF key bindings and Catppuccin syntax colors
- **Smart CLI wrappers** that prefer modern tools (`eza`, `bat`, `btop`, `dust`, `prettyping`) with graceful fallbacks
- **Auto Python venv** activation on directory change (direnv-aware)
- **Kitty terminal** deep integration for splits, tabs, and SSH
- **AI workflow** helpers for Claude and Gemini session management
- **WakaTime** shell activity tracking

---

## Structure

```
~/.config/fish/
├── config.fish           # Main entry point
├── fish_plugins          # Fisher plugin list
├── fish_variables        # Universal variables
├── conf.d/               # Auto-sourced configuration fragments
│   ├── abbr.fish         # All abbreviations
│   ├── cheat.fish        # cheat.sh completions
│   ├── key_bindings.fish # Custom key bindings
│   ├── fzf.fish          # FZF key binding initialization
│   ├── tailscale.fish    # Tailscale CLI completions
│   ├── theme.fish        # Theme syntax highlighting colors
│   ├── done.fish          # Done plugin (desktop notifications for long commands)
│   ├── tricks.fish       # PATH, bang-bang helpers, bat man pages, system aliases, history/backup utilities
│   ├── paru-wrapper.fish # Auto-generates ~/.local/bin/paru logging wrapper on first run
│   ├── yay-wrapper.fish  # Auto-generates ~/.local/bin/yay logging wrapper on first run
│   ├── starship.fish     # fish_prompt with OSC 133;A/B shell-integration markers
│   ├── wakatime.fish     # WakaTime shell hook
│   └── zoxide.fish       # Zoxide z/zi aliases
├── docs/                 # Offline documentation
│   ├── fish-config.md    # Primary offline reference manual (terminal-readable)
│   └── fish-config.index # Section index for config_help navigation
├── functions/            # Custom functions (one per file)
├── completions/          # Custom tab completions
├── integrations/         # Integration scripts
│   └── fzf.fish          # FZF theme and binding config
└── themes/               # Catppuccin theme files
    ├── Catppuccin Mocha.theme
    ├── Catppuccin Macchiato.theme
    ├── Catppuccin Frappe.theme
    └── Catppuccin Latte.theme
```

---

## Plugins

Managed via [Fisher](https://github.com/jorgebucaran/fisher):

| Plugin | Purpose |
|---|---|
| `jorgebucaran/fisher` | Plugin manager |
| `patrickf1/fzf.fish` | FZF key bindings for history, files, processes, git |
| `catppuccin/fish` | Catppuccin Mocha syntax highlighting |
| `jorgebucaran/autopair.fish` | Auto-close brackets, quotes, and other pairs |
| `jorgebucaran/replay.fish` | Run bash commands in fish without losing state |
| `nickeb96/puffer-fish` | Expand `...` to `../..`, `!!` to last command, etc. |
| `jorgebucaran/spark.fish` | Sparkline bar charts in the terminal |

Fisher and all listed plugins are installed automatically by the bootstrap script in `config.fish` upon launching the shell for the first time.

---

## Theme & Prompt

### Starship

The primary prompt is [Starship](https://starship.rs/), managed via `conf.d/starship.fish`. Configure it via `~/.config/starship.toml`.

`conf.d/starship.fish` defines a `fish_prompt` wrapper that only activates when `starship` is in `PATH`. It emits OSC 133;A (prompt start) immediately before Starship renders and OSC 133;B (input start) immediately after, placing both markers on the prompt line itself rather than on the blank line above it. This enables `ov` to use them as sticky section headers when browsing scrollback logs. Without Starship, fish's built-in prompt already handles these markers correctly with no wrapper needed.

### FZF

FZF is themed to Catppuccin Mocha with the following colors set via `FZF_DEFAULT_OPTS`:

- Background: `#1E1E2E` / `#313244`
- Foreground: `#CDD6F4`
- Highlights: `#F38BA8` (red), `#CBA6F7` (mauve), `#B4BEFE` (lavender)

See [FZF Bindings](#fzf-bindings) under Key Bindings for the default FZF shortcuts.

---

## Integrations

> [!NOTE]
> All integrations listed below are designed to gracefully fallback to basic commands or safely ignore their configuration if their required external dependencies are not installed on the system.

### Zoxide

Smart `cd` replacement powered by frecency scoring. `cd`, `z`, and `cdi`/`zi` are all mapped to zoxide-backed navigation functions.

| Command | Description |
|---|---|
| `cd <path>` / `z <path>` | Jump to a matching directory by frecency; falls back to exact path |
| `cdi` / `zi` | Open an interactive fzf selector across all frecency-ranked directories |

Tab completions for `cd` and `z` blend standard directory entries (CWD and `CDPATH`) with zoxide frecency results, so familiar paths and frequently-visited destinations appear together in a single list. Full tab completions for the `zoxide` CLI itself (subcommands: `add`, `query`, `remove`, `import`, `init`) are provided via `completions/zoxide.fish`.

### DirEnv

Automatically loads `.envrc` files on directory change. Takes priority over the built-in auto-venv logic.

### Auto Python Venv

When entering a directory containing a `.venv/`, the virtualenv is automatically activated.  
It is automatically deactivated when you leave the project tree.

> [!TIP]
> DirEnv-managed directories are skipped by the auto-venv logic to avoid conflicts.

### WakaTime

Every shell command is reported to WakaTime for time-tracking. Disable by setting `FISH_WAKATIME_DISABLED=1`.

### Tailscale

Full tab completion for the `tailscale` CLI is provided via `conf.d/tailscale.fish`.

### Pager

`$PAGER` is set in `config.fish` to `ov` when available, falling back to `less`. This ensures any application that honours `$PAGER` (git, man, etc.) uses the configured pager automatically.

The `less` wrapper function implements a full pager hierarchy, so anything that calls `less` directly also benefits:

```
$PAGER → ov → less → more → cat
```

| Variable | Default | Description |
|---|---|---|
| `PAGER` | `ov` (if installed), else `less` | System-wide pager used by `less`, `logs`, and any tool that honours `$PAGER` |

### bat Man Pages

When `bat` is installed, man pages are automatically rendered through it for syntax highlighting. `MANPAGER` and `MANROFFOPT` are set in `conf.d/tricks.fish`:

```fish
set -gx MANROFFOPT -c
set -gx MANPAGER "sh -c 'col -bx | bat -l man -p'"
```

### Done Notifications

Desktop notifications for long-running commands via [franciscolourenco/done](https://github.com/franciscolourenco/done). A notification fires when a command takes longer than 10 seconds and the terminal window is not focused.

| Variable | Value | Description |
|---|---|---|
| `__done_min_cmd_duration` | `10000` ms | Minimum duration before a notification is sent |
| `__done_notification_urgency_level` | `low` | Desktop notification urgency |

### Scrollback History

When running inside Kitty, closing a shell session with `exit` automatically saves a timestamped scrollback snapshot to `SCROLLBACK_HISTORY_DIR` (default: `~/.terminal_history`). Snapshots are named `scrollback_YYYY-MM-DD_HH-MM-SS.log` and the oldest files are pruned automatically once the count exceeds `SCROLLBACK_HISTORY_MAX_FILES`.

The `paru` and `yay` wrappers (auto-generated in `~/.local/bin/` by `conf.d/paru-wrapper.fish` and `conf.d/yay-wrapper.fish`) tee all AUR helper output to timestamped log files (`paru_YYYY-MM-DD_HH-MM-SS.log` / `yay_YYYY-MM-DD_HH-MM-SS.log`) in the same directory.

Before pruning to the max-files limit — and before displaying the log browser — junk logs are automatically removed by `_scrollback_prune_junk`: empty files, files with only a single meaningful line (e.g. bare `[exited]` captures), and Kitty tab-rename prompt captures are all silently discarded.

Use `exit --no-log` (or `exit -n`) to close without saving.

The `cat` function detects files inside `SCROLLBACK_HISTORY_DIR` (and any file containing raw ANSI escape sequences) and pipes them through `command cat` instead of `bat`, preserving color output.

Both variables can be overridden in `local.fish`:

| Variable | Default | Description |
|---|---|---|
| `SCROLLBACK_HISTORY_DIR` | `~/.terminal_history` | Directory where scrollback snapshots are written |
| `SCROLLBACK_HISTORY_MAX_FILES` | `100` | Maximum number of snapshots to keep before pruning |

---

## Key Bindings

### FZF Bindings

These are the default FZF bindings (from `fzf.fish`):

| Binding | Action |
|---|---|
| `Ctrl+R` | Search command history |
| `Ctrl+Alt+F` | Search git-tracked files |
| `Ctrl+Alt+L` | Search git log |
| `Ctrl+Alt+S` | Search git status |
| `Ctrl+V` | Search shell variables |
| `Ctrl+Alt+P` | Search running processes |

### User Bindings

Beyond standard shell and FZF bindings, these custom interactive shortcuts are available:

| Binding | Action | Description |
|---|---|---|
| `Ctrl+G` | Previous Path Head | Behaves like `!$:h` in Bash. Inserts the directory part of the previous command's last argument. |
| `Ctrl+F` | Interactive History Substitution | Behaves like `!!:s/old/new/` in Bash. Performs substitution on the previous command using `old/new` syntax. When no text is entered, prepends `sudo` to the previous command. The `old/new/n` syntax will perform substitution on the command `n` lines previous in the history. |
| `Ctrl+Alt+U` | Replace Command Token | Strips the first token (the command) from the current line. **If the line is empty**, it pulls the previous command and strips its first token, placing the cursor at the start for a quick replacement (e.g., changing `mkdir` to `cd` while keeping the paths). |
| `Ctrl+Alt+=` | Inline Qalculate! Evaluation | Passes the current command-line buffer to `qalc` (Qalculate!) and prints the result, then clears the buffer. Allows rapid-fire math without leaving the shell — type `150 * 1.08`, press `Ctrl+Alt+=`, and see `162` immediately. |
| `Ctrl+Enter` | Smart Execute | Context-aware Enter key. Empty buffer → standard Enter. Buffer ending with `=` → evaluates it as a math expression via `qalc` (same as `Ctrl+Alt+=`). Any other content → executes the command normally. |
| `@@` | FZF Inline Picker | Opens an interactive `fzf` session and injects the selected item directly at the cursor position in the current command line. Useful for inserting file paths, branch names, or any fzf-searchable content mid-command. |

---

## Functions

### Modern CLI Replacements

These functions wrap modern alternatives with graceful fallbacks to standard tools.

| Function | Replaces | Tool |
|---|---|---|
| `ls` | `ls` | `eza` (falls back to `lsd`, then system `ls`) |
| `cat` | `cat` | `bat` (plain, no pager); falls back to `command cat` for ANSI log files and scrollback snapshots |
| `less` | `less` | `ov` (modern pager); falls back to `less` → `more` → `cat` |
| `ping` | `ping` | `prettyping --nolegend` |
| `top` | `top` | `btop` |
| `rg` | `rg` | ripgrep with `--hyperlink-format=kitty` |
| `ssh` | `ssh` | `kitten ssh` when inside Kitty |
| `du` | `du` | `duf` (disks) / `dust` (directories) — auto-detected by argument |
| `mkdir` | `mkdir` | Always passes `-p` in interactive mode; reports created directories as `Created directory: ~/path/` (falls back silently when flags like `-m` are present) |
| `copy` | `cp` | Strips trailing `/` from a source directory before `cp -r`; falls through to `cp` for all other cases |

#### `du` — Smart Disk Usage

```fish
du              # → duf  (disk overview)
du /some/dir    # → dust (directory breakdown)
du --disk       # → duf  (force disk view)
du --dir        # → dust (force directory view)
du --dua        # → dua  (interactive mode)
```

#### `rm` — Trash-Aware Remove

```fish
rm              # List current trash contents
rm file.txt     # Move to trash (recoverable)
rm -r dir/      # Move directory to trash
rm -e           # Empty all trash
rm -e --within 2weeks  # Empty trash older than 2 weeks
rm -S file.txt  # Permanent secure delete + fstrim
rm -f file.txt  # Falls through to standard rm -f
```

### Directory & File Listing

| Function | Description |
|---|---|
| `mkcd <dir> [-s]` | Create directory (including missing parents) and `cd` into it; shows a tree of newly-created dirs by default; `-s`/`--silent` suppresses the tree |
| `poke <file>...` | `touch` with automatic parent directory creation; shows a tree of newly-created dirs |
| `ls` | `eza` — long listing, all files, icons, color, hyperlinks |
| `lss` | `eza` — size-sorted long listing with gradient color scale |
| `lsr` | `eza` — reversed time-sorted oneline listing |
| `ltr` | `eza` — long listing, reversed modification time, age color scale |
| `lD` | `eza` — directories only |
| `lx` | `eza` — long listing sorted by extension |
| `lt` | `eza` — tree listing, depth 2 |
| `lstree` | `eza` — full recursive tree |

### Git

| Function | Description |
|---|---|
| `branch` | Switch to or create a git branch |
| `gitup` | Fetch updates and show git status |
| `git-clean` | Fetch, prune, update current branch, delete orphaned local branches |
| `git-clean --force` | Same but force-deletes unmerged orphaned branches |
| `clone` | `clone-in-kitty` wrapper |
| `gitui` | Fast terminal Git UI |
| `gi` | Generate and append `.gitignore` patterns from gitignore.io; `gi` (no args) appends boilerplate then prompts interactively; `gi <targets>` appends named patterns; `gi -s <targets>` prints to stdout; `gi -l` lists all targets |

### Package Management

| Function | Description |
|---|---|
| `pkg <name>...` | Toggle package: installs if missing, removes if present; `-i` force-install, `-u` force-uninstall. Auto-detects the system package manager (paru, yay, pacman, apt, dnf, zypper, yum, brew, pkg) |
| `search <query>` | Search/install interactively: `paru <query>` (Arch only) |
| `upgrade` | Full system upgrade: `paru -Syu --noconfirm` (Arch only) |
| `cleanup` | Log and remove orphaned packages |

`conf.d/paru-wrapper.fish` and `conf.d/yay-wrapper.fish` auto-generate thin wrapper scripts at `~/.local/bin/paru` and `~/.local/bin/yay` on first shell start (when the respective AUR helper is installed). These wrappers tee all output to timestamped log files in `SCROLLBACK_HISTORY_DIR` and prune old logs to stay under `SCROLLBACK_HISTORY_MAX_FILES`.

### Offline Documentation

A curated offline reference manual is available at `docs/fish-config.md`. It covers every function, keybinding, abbreviation, and configuration variable, written for terminal readability (no hyperlinks or GitHub-specific callouts).

| Command | Description |
|---|---|
| `config_help` | Open the offline manual in the best available pager |
| `config_help <keyword>` | Jump directly to a section matching the keyword |

The viewer falls back through: **ov** (syntax highlight + section navigation) → **bat** (syntax highlight) → **man -l** (pre-compiled man page) → **less** → **cat**.

Examples: `config_help keybindings` · `config_help pkg` · `config_help fish-deps` · `config_help abbreviations`

### Dependency Management

`fish-deps` is a unified command for checking, installing, and updating all tools this config depends on.

| Command | Description |
|---|---|
| `fish-deps` / `fish-deps status` | Show installed/missing status for all deps, grouped by tier |
| `fish-deps install` | Interactively install each missing dep (prompts per-dep, prompts method when multiple exist) |
| `fish-deps update` | Update all installed deps using their preferred install method |
| `fish-deps sync` | Install missing deps then update installed ones |
| `fzf-update` | Install or upgrade fzf from git HEAD into `~/.fzf` (guarantees the latest build) |
| `check_fish_deps` | Legacy alias — delegates to `fish-deps status` |

Install method priority: **git+cargo source build** (fish) → **cargo** (other Rust tools, gets latest crate) → **system PM** (paru/apt/brew/etc.) → **git clone** (fzf) → **curl installer** (starship, fisher) → **pipx** (Python tools). When multiple methods are available for a tool, you are prompted to choose.

> [!NOTE]
> Upgrading Fish from source requires **cargo** and **[uv](https://docs.astral.sh/uv/)**. Both are managed dependencies — `fish-deps install` will offer to install them before attempting the Fish build. If both are unavailable, `fish-deps update` falls back to the system package manager.

### Docker

| Function | Description |
|---|---|
| `ld` / `lzd` | Launch LazyDocker using the currently active Docker context |
| `dockup [dir]` | Pull latest images and restart docker compose services |
| `docker ps` | Intercepted to use `dops` for a prettier process listing |

### Network

| Function | Description |
|---|---|
| `gip` | Show both public IPv4 and IPv6 addresses |
| `gip4` | Show public IPv4 address only |
| `gip6` | Show public IPv6 address (or error if unavailable) |
| `ports` | List all active TCP listeners via `lsof` |
| `fast-cli` | Run a bandwidth speed test using fast.com |
| `fast` | Friendly error shown when `fast` is typed instead of `fast-cli` |

### Clipboard

| Function | Description |
|---|---|
| `y <text>` | Copy text to clipboard (Wayland `wl-copy` or X11 `xclip`) |
| `cb <text>` | Copy to clipboard (alias for `y`) |
| `paste` | Paste from clipboard to stdout |

### Terminal

| Function | Description |
|---|---|
| `split [-h\|-v] [cmd]` | Open a new split pane, optionally running a command |
| `spwin` | Spawn a new OS window |
| `detach <cmd>` | Run a command fully detached (`nohup`), no output |
| `bkg <cmd>` | Background a command, discarding all output |

### System

| Function | Description |
|---|---|
| `lock` | Lock the session via `loginctl lock-session` |
| `screensleep` | Turn off the display via KDE PowerDevil |
| `wake-lock <cmd>` | Run a command with `systemd-inhibit` to prevent sleep |
| `swapstat` | Colorized zRAM compression ratio, swappiness, and swap priority report |
| `sudo-toggle` | Toggle sudo password bypass — writes/clears a `NOPASSWD` rule in `/etc/sudoers.d/nofail-toggle` |
| `smart_exit` | Captures Kitty terminal scrollback to a timestamped log on exit; `--no-log` skips capture; runs `_scrollback_prune_junk` then auto-prunes oldest logs when count exceeds `SCROLLBACK_HISTORY_MAX_FILES` |
| `logs` | Browse scrollback, paru, and yay log files interactively with fzf; `Enter` opens in `$PAGER`, `Ctrl-E` opens in `$EDITOR`, `Ctrl-D` deletes (with Y/n confirm), `?` toggles a keybind help overlay; `-c <category>` filters to `scrollback`, `paru`, or `yay`; paru/yay logs open in `ov` with syntax highlights and sticky section headers; scrollback logs open in `ov` with per-command sticky prompt headers via OSC 133;A markers |
| `psmem` | List all processes sorted by memory usage (descending) |
| `psmem10` | Top 10 processes by memory usage |
| `tmux-clean` | Kill all detached tmux sessions |
| `limine-edit` | Safely edit and re-verify Limine bootloader configuration |
| `sbver` | Verify bootloader signing status for Secure Boot |

### Media & Utilities

| Function | Description |
|---|---|
| `dng2avif` | Convert DNG raw images to 10-bit HDR AVIF |
| `steam-dl` | Run Steam while inhibiting system sleep |

### Editors & Development

| Function | Description |
|---|---|
| `edit` / `e` | Open in Neovim (or `$EDITOR`) |
| `view` | Open in Neovim read-only mode |
| `fc` | Edit and execute the last command (Bash-style `fc`) |
| `nvimup` | Update Neovim headlessly |
| `nlazyup` | Sync Lazy.nvim plugins headlessly |

### AI Assistants

| Function | Description |
|---|---|
| `claude` | Wrapper for `claude` that always injects `--remote-control` (skips if already present) |
| `claude-resume` | Resume Claude Code session from `.claude_session` in CWD |
| `antigravity-resume` | Resume antigravity-cli session from `.antigravity_session` in CWD |
| `code-resume` | Smart resume — tries Claude then antigravity-cli, falls back to picker |
| `superpowers [on\|off]` | Enable/disable the Superpowers extension for Claude and antigravity-cli |
| `claude-docs` | Ask Claude to sync `README.md` with recent session changes |
| `claude-pr` | Create a branch, commit, push, and open a PR via Claude |

### Fetch & Info

| Function | Description |
|---|---|
| `ffetch` | Run fastfetch with `~/.fastfetch.jsonc` if present |
| `cffetch` | Clear screen then run fastfetch |
| `hist` | FZF history search — selected command is placed in the prompt and copied to clipboard |
| `history` | Built-in `history` override — prepends `YYYY-MM-DD HH:MM:SS` timestamps to every entry |
| `qr <text>` | Generate a terminal QR code |

### Miscellaneous

| Function | Description |
|---|---|
| `upgrade` | System upgrade via paru |
| `zellij` | Zellij with `--theme catppuccin-mocha` |
| `scrub` | Recursively purge OS/editor/compiler garbage from CWD; `-a` aggressive mode adds logs, `node_modules`, IDE dirs; `-d` dry-run preview; requires `fd` |
| `antigravity` | Wrapper for `agy` (antigravity-cli) that suppresses a noisy warning |
| `antigravity-ide` | Wrapper for `antigravity-ide` binary that suppresses a noisy warning |
| `backup <file>` | Copy `<file>` to `<file>.bak` |
| `bash` | Drop into bash (raw Fish session via `rawfish`) |

### Shell Aliases

These aliases are defined in `conf.d/tricks.fish` via `alias` (which creates Fish functions). They are active in all interactive sessions.

#### Navigation

| Alias | Expands To |
|---|---|
| `..` | `cd ..` |
| `...` | `cd ../..` |
| `....` | `cd ../../..` |
| `.....` | `cd ../../../..` |
| `......` | `cd ../../../../..` |

#### Color Overrides

Force color output for common tools:

| Alias | Command |
|---|---|
| `grep` | `grep --color=auto` |
| `fgrep` | `fgrep --color=auto` |
| `egrep` | `egrep --color=auto` |
| `dir` | `dir --color=auto` |
| `vdir` | `vdir --color=auto` |

#### Safety Wrappers

These aliases add `-i` (interactive confirmation) to destructive commands:

| Alias | Command |
|---|---|
| `cp` | `cp -i` |
| `mv` | `mv -i` |

#### Archives & Networking

| Alias | Command | Description |
|---|---|---|
| `tarnow` | `tar -acf` | Create a compressed archive (auto-detects format from extension) |
| `untar` | `tar -zxvf` | Extract a gzip-compressed archive |
| `wget` | `wget -c` | Resume interrupted downloads by default |
| `tb` | `nc termbin.com 9999` | Pipe content to [termbin.com](https://termbin.com) for quick sharing |

#### System Logs

| Alias | Command | Description |
|---|---|---|
| `jctl` | `journalctl -p 3 -xb` | Show priority-3 (error) journal entries from the current boot |

---

## Abbreviations

Abbreviations expand in-place as you type, keeping your history clean.

### History Expansions (Bash-style)

These abbreviations replicate Bash's bang-style history expansions. They expand anywhere in the command line when a trigger key (like `Space` or `Enter`) is pressed.

| Abbr | Expansion | Description |
|---|---|---|
| `!^` | First argument | Expands to the first argument of the previous command |
| `!*` | All arguments | Expands to all arguments of the previous command |
| `!-n` | n-th previous | Expands to the n-th previous command in history (e.g., `!-2`) |
| `!string` | Prefix search | Expands to the most recent command starting with `string` |
| `!?string?` | Contains search | Expands to the most recent command containing `string` |
| `^old^new` | Quick substitution | Replaces `old` with `new` in the previous command and expands to it |

### Editors

| Abbr | Expands To |
|---|---|
| `n`, `nv` | `nvim` |
| `e` | `edit` |
| `se` | `sudoedit` |
| `v` | `antigravity-ide` (VSCode-equivalent) |
| `k` | `kate` |

### Listing

| Abbr | Expands To |
|---|---|
| `l` | `ls` |
| `lS` | `lss` (size-sorted) |
| `lsR` | `lsr` (reversed time) |
| `lX` | `lx` (extension-sorted) |
| `lT` | `lt` (tree, depth 2) |
| `lsT` | `lstree` (full tree) |

### Navigation

| Abbr | Expands To |
|---|---|
| `cdnv` | `cd ~/.config/nvim` |
| `:cdf` | `cd ~/.config/fish/` |
| `:cdk` | `cd ~/.config/kitty/` |
| `:cdh` | `cd ~` |
| `:cdp` | `cd ~/projects/` (with cursor placement) |
| `:cdcz` | `cd ~/.local/share/chezmoi/` |

### Git

| Abbr | Expands To |
|---|---|
| `g` | `git` |
| `lg` | `lazygit` |
| `gitig` / `git-ignore` | `gi` |

### Chezmoi

| Abbr | Expands To |
|---|---|
| `cm` / `cz` | `chezmoi` |
| `cmcd` | `chezmoi cd` |
| `cme` | `chezmoi edit` |
| `cmad` | `chezmoi add` |
| `cmap` | `chezmoi apply` |
| `cmf` | `chezmoi forget` |
| `cmi` | `chezmoi init` |

### Kitty / WezTerm Window Management

These abbreviations mirror Vim/tmux ergonomics for managing terminal splits, tabs, and windows. They automatically detect whether you are using Kitty or WezTerm and execute the appropriate terminal CLI commands.

| Abbr | Action |
|---|---|
| `:q` | Close active pane |
| `:Q` | Close active tab |
| `:w` | New OS window |
| `:t` | New tab |
| `:wv` | Horizontal split |
| `:wh` | Vertical split |
| `:tp` / `:tn` | Navigate tabs left/right |
| `:tl "Title"` | Rename current tab |
| `:tgn` | New tab in `~/.config/nvim` |
| `:tgf` | New tab in `~/.config/fish` |
| `:tgp` | New tab in `~/projects` |
| `:tgr` | New root tab (`sudo -i`) |

### SSH

Machine-specific SSH abbreviations (e.g. `sshr`, `sshrt`) live in `~/.config/.user-dots/fish/local.fish`.
(See [Personalization](#personalization) for examples)

### Docker

| Abbr | Expands To |
|---|---|
| `dcl` | `docker context use default` |
| `dcls` | `docker context ls` |
| `lzd` | `ld` (LazyDocker) |

Named context shortcuts (e.g. `dcr`, `dck`) live in `~/.config/.user-dots/fish/local.fish`.
(See [Personalization](#personalization) for examples)

### Systemctl

| Abbr | Expands To |
|---|---|
| `sc` | `systemctl` |
| `ssc` | `sudo systemctl` |
| `scu` | `systemctl --user` |
| `st` | `systemctl status` |
| `scs` | `systemctl start` |
| `scr` | `systemctl restart` |
| `ssct` | `sudo systemctl status` |
| `sscs` | `sudo systemctl start` |
| `sscr` | `sudo systemctl restart` |

### Speed Test

| Abbr | Expands To |
|---|---|
| `speedtest-fast` | `fast-cli` (speed test via fast.com) |

### Beads (bd)

| Abbr | Expands To |
|---|---|
| `bl` | `bd list` |
| `bs` | `bd sync` |
| `bC` | `bd create --title` |
| `bsh` | `bd show` |
| `lb` | `lazybeads` |

---

## Dependencies

### Required

| Tool | Version | Purpose |
|---|---|---|
| [uv](https://docs.astral.sh/uv/) | any | Python runner (needed to build Fish from source) |
| [Rust / cargo](https://www.rust-lang.org/tools/install) | any | Installs Rust-based tools; required to build Fish |
| [Fish](https://fishshell.com/) | **≥ 4.0** | Shell |
| [Fisher](https://github.com/jorgebucaran/fisher) | any | Plugin manager |
| [Starship](https://starship.rs/) | any | Prompt |
| [fzf](https://github.com/junegunn/fzf) | any | Fuzzy finder |
| [zoxide](https://github.com/ajeetdsouza/zoxide) | any | Smart directory jumper |
| [direnv](https://direnv.net/) | any | Per-directory env loading |

> [!WARNING]
> Fish **4.0 or newer is required.** This config uses `test` syntax and other constructs that are incompatible with Fish 3.x. Older versions will produce errors on startup.
> Run `fish-deps install` or `fish-deps update` to upgrade — it will install `uv` and `cargo` automatically if missing, then build the latest Fish from source.

### Recommended

| Tool | Replaces |
|---|---|
| [Rust / cargo](https://www.rust-lang.org/tools/install) | Build tool for Rust-based CLI replacements below |
| [paru](https://github.com/Morganamilo/paru) / [yay](https://github.com/Jguer/yay) | AUR helper (Arch only) |
| [eza](https://github.com/eza-community/eza) | `ls` (preferred) |
| [lsd](https://github.com/lsd-rs/lsd) | `ls` (fallback) |
| [bat](https://github.com/sharkdp/bat) | `cat` |
| [btop](https://github.com/aristocratsupply/btop) | `top` |
| [dust](https://github.com/bootandy/dust) | `du` (directories) |
| [duf](https://github.com/muesli/duf) | `du` (disks) |
| [prettyping](https://github.com/denilsonsa/prettyping) | `ping` |
| [ov](https://github.com/noborus/ov) | `less` / `$PAGER` |
| [ripgrep](https://github.com/BurntSushi/ripgrep) | `grep` |
| [lazygit](https://github.com/jesseduffield/lazygit) | git TUI |
| [lazydocker](https://github.com/jesseduffield/lazydocker) | Docker TUI |
| [trash-cli](https://github.com/andreafrancia/trash-cli) | Safe `rm` |
| [Kitty](https://sw.kovidgoyal.net/kitty/) / [WezTerm](https://wezfurlong.org/wezterm/) | Terminal emulator |
| [WakaTime](https://wakatime.com/) | Activity tracking |

### Full Requirements

For a complete, categorized list of all non-standard tools required or used by this configuration, see [requirements.md](requirements.md).

---

## Installation

This config is managed as a Git repository. To use it on a new machine:

```fish
# Back up any existing config
mv ~/.config/fish ~/.config/fish.bak

# Clone this repo
git clone https://git.rootiest.dev/rootiest/fish-config.git ~/.config/fish
```

Then open a new Fish shell — Fisher and all plugins will be installed automatically on first launch, and the Catppuccin Mocha theme will be applied.

A [chezmoi](https://www.chezmoi.io/) dotfile manager is also configured — secrets are sourced from `~/.config/.user-dots/fish/secrets.fish` and excluded from version control.

> [!IMPORTANT]
> `config.fish` ends with a `return` sentinel guard. Any lines appended **after** it by a tool's setup command will silently have no effect. Many tools (starship, zoxide, mise, etc.) offer a setup command that appends an `init | source` line to your `config.fish` — all integrations are managed through `conf.d/` files instead. If you add a new tool and its shell integration appears to do nothing, check whether its setup command appended an init line to the bottom of `config.fish` and create a `conf.d/<tool>.fish` file for it instead.

---
## Personalization

Sensitive credentials and machine-specific paths are kept out of version control via a secondary private directory at `~/.config/.user-dots/fish/`. Two files are sourced automatically by `config.fish` if they exist:

```
~/.config/.user-dots/fish/
├── secrets.fish   # API keys, tokens, passwords, personal identifiers
└── local.fish     # Machine-specific paths and environment variables
```

### secrets.fish

Use this file for anything you would not commit to a public repo: API keys, auth tokens, passwords, and personal identifiers like usernames or email addresses.

```fish
# ~/.config/.user-dots/fish/secrets.fish

### Identity ###
set -gx MY_NAME "Your Name"
set -gx MY_EMAIL "you@example.com"
set -gx GPG_RECIPIENT "you@example.com"

### API Keys & Tokens ###
set -gx GITHUB_TOKEN ghp_yourTokenHere
set -gx OPENAI_API_KEY sk-proj-yourKeyHere
set -gx GITEA_TOKEN yourGiteaTokenHere
set -gx GITEA_CHOSEN_LOGIN your.gitea.instance
set -gx TEA_LOGIN your.gitea.instance

### Backup ###
set -gx KOPIA_PASSWORD yourKopiaPassword
```

### local.fish

Use this file for paths and variables that are specific to one machine — things that would break or be wrong on any other system.

```fish
# ~/.config/.user-dots/fish/local.fish

# CDPATH — directories searched by cd
set -gx CDPATH . /home/youruser/projects /home/youruser

# Path to your shared .gitignore boilerplate (used by `gi -b` / `gi` default)
set -gx GITIGNORE_BOILERPLATE ~/.config/git/gitignore_boilerplate

### SSH ###
# Quick shortcuts to your own servers
abbr -a sshr 'ssh you@your-server.local'
abbr -a sshw 'ssh you@work-server.example.com'

### Docker contexts ###
# Named shortcuts for your own Docker contexts (docker context ls)
abbr -a dcr 'docker context use my-remote-server'
abbr -a dcw 'docker context use work-server'
```

### How it works

`config.fish` sources both files with an existence check so the public config works cleanly on any machine that doesn't have the private repo:

```fish
if test -f $HOME/.config/.user-dots/fish/secrets.fish
    source $HOME/.config/.user-dots/fish/secrets.fish
end

if test -f $HOME/.config/.user-dots/fish/local.fish
    source $HOME/.config/.user-dots/fish/local.fish
end
```

`fish_variables` (which fish auto-manages and may contain universal variable state) is excluded from this repo via `.gitignore`.

---

## Attribution

The core of the [Zoxide integration](#zoxide) in this repository was originally adapted from the [icezyclon/zoxide.fish](https://github.com/icezyclon/zoxide.fish) plugin (MIT Licensed) and has since been heavily customized for performance and Fish 4.x compatibility.

---

## License

Copyright (C) 2026 Rootiest

This project is licensed under the **GNU Affero General Public License v3.0 or later** (AGPLv3+).
See the [LICENSE](LICENSE) file for the full license text.
