# Fish Shell Configuration

A feature-rich Fish shell configuration for CachyOS (Arch Linux),
built around a Catppuccin Mocha aesthetic with a curated set of modern
CLI tool integrations, smart shell functions, and a heavily customized
abbreviation system for keyboard-driven workflows.

📖 **[Documentation site](https://fish.rootiest.fyi/)**

## Table of Contents

- [Overview](#overview)
- [Session Logging](#session-logging)
- [Documentation](#documentation)
- [Installation](#installation)
- [Personalization](#personalization)
- [Minimal Mode](#minimal-mode)
- [Attribution](#attribution)
- [License](#license)

---

## Overview

This config layers on top of the CachyOS base Fish configuration and adds:

- **Catppuccin Mocha** theming throughout (prompt, FZF, syntax highlighting)
- **Starship** prompt with VI key bindings; Catppuccin Mocha nim-style fallback prompt when Starship is absent or C3 overrides are disabled
- **Fisher** plugin manager bootstrapped automatically; manages `sponge` (failed-command history filter); FZF bindings, Catppuccin theme, done, autopair, and puffer-fish are bundled directly with the config as customized versions
- **Smart CLI wrappers** that prefer modern tools (`eza`, `bat`, `btop`, `dust`, `prettyping`) with graceful fallbacks
- **Auto Python venv** activation on directory change (direnv-aware)
- **Kitty terminal** deep integration for splits, tabs, and SSH
- **Automatic session logging** — terminal scrollback, multiplexer panes (tmux/zellij), and AUR-helper output are captured to `~/.terminal_history` (see the caution below and [Session Logging](#session-logging))
- **AI workflow** helpers for Claude and Antigravity session management
- **WakaTime** shell activity tracking
- **Opt-out toggles** for every opinionated component — see [Minimal Mode](#minimal-mode)

> [!CAUTION]
> **This configuration logs your terminal sessions to disk by default.**
> Out of the box it silently captures terminal output to `~/.terminal_history`:
> Kitty scrollback when a window closes, live tmux pane streams, zellij pane
> snapshots on exit, and full `paru`/`yay` output. These logs can contain
> command output, file contents, and anything else printed to your terminal.
> Nothing is sent off your machine, but the files persist locally until pruned.
>
> To turn all logging off, set the C5 category variable:
>
> ```fish
> set -U __fish_config_op_logging off
> ```
>
> Or run **`config-settings`** for an interactive menu to flip logging (and any
> other opinionated category) on or off — no variable names to remember.
>
> This takes effect immediately in every open shell. See [Session Logging](#session-logging)
> for exactly what is captured and where, and [Minimal Mode](#minimal-mode) for the
> full set of opt-out toggles.

---

## Session Logging

This config captures terminal output to `~/.terminal_history` (override with
`$SCROLLBACK_HISTORY_DIR`) so you can search back through past sessions. It is
**on by default**. Five sources feed it:

| Source | When it captures | Log file |
|---|---|---|
| Kitty scrollback | When a Kitty window/tab closes | `scrollback_<timestamp>.log` |
| tmux pane | Continuously while the pane is open (`pipe-pane`) | `tmux_<session>-w<win>-p<pane>_<timestamp>.log` |
| zellij pane | Snapshot taken on **clean** shell exit (`dump-screen`) | `zellij_<session>-p<pane>_<timestamp>.log` |
| `paru` wrapper | Every `paru` invocation | `paru_<timestamp>.log` |
| `yay` wrapper | Every `yay` invocation | `yay_<timestamp>.log` |

Old logs are pruned automatically to stay within `$SCROLLBACK_HISTORY_MAX_FILES`
(default 100) per source, and empty/trivial captures are discarded.

> **zellij caveat:** zellij has no continuous pipe like tmux, so its pane is
> snapshotted only on a clean shell exit (`exit`/Ctrl-D). Closing a pane or
> quitting zellij directly tears down the pane/server before it can be dumped,
> so those sessions are not logged. End with `exit` to guarantee a log.

**These logs can contain secrets** — anything printed to your terminal (command
output, file dumps, tokens echoed to stdout) ends up in them. They never leave
your machine, but treat `~/.terminal_history` as sensitive.

Disable all of it with a single universal variable:

```fish
set -U __fish_config_op_logging off   # disable; takes effect in every open shell
set -Ue __fish_config_op_logging      # re-enable (erase the override)
```

Prefer an interactive interface? Run **`config-settings`** for a full-screen
picker that flips logging — and every other opinionated category — on or off
per session or universally, without memorizing variable names.

Disabling also removes the generated `paru`/`yay` log wrappers and tells the
Kitty watcher to skip capture via a sentinel file — no shell or terminal
restart required. Logging is category **C5** in [Minimal Mode](#minimal-mode);
`set -U __fish_config_opinionated 0` turns it off along with everything else.

The Kitty scrollback capture is provided by a watcher script that fish-config can
install and manage for you. Inside Kitty, if it isn't set up yet, you'll see a
one-time-per-session reminder. Manage it with:

| Command | Action |
|---|---|
| `kitty-logging install` | Symlink the watcher into your Kitty config and wire it into `kitty.conf` |
| `kitty-logging uninstall` | Remove the managed block and the watcher symlink |
| `kitty-logging status` | Show whether it's wired, the watcher version, and C5 state |
| `kitty-logging dismiss` | Stop the per-session reminder without installing |

`install` adds a clearly-marked managed block to `kitty.conf` and comments out
any conflicting `watcher` line. It affects **new** Kitty windows (existing
windows keep their current watcher until restarted). Disabling C5 logging makes
the watcher inert without uninstalling it.

---

## Documentation

### [📖 Documentation Site](https://fish.rootiest.fyi/)

A Starlight-powered site rebuilt on every push to `main`. It covers
configuration variables, key bindings, abbreviations, all functions, the
dependency catalog, customization, and more, with full-text search.

Contributing to the docs? There are two sources, split by content type:

- **Function documentation** comes from the man-page-style comment header
  above each function in `functions/*.fish`. Edit the function; the entry
  and its site page are generated from the header.
- **Everything else** lives under `docs/manual/**`.

Never edit the generated `docs/fish-config.md` — it's rebuilt from both
sources and any hand-edits are discarded.

To browse the docs from the terminal:

| Command | Description |
|---|---|
| `help config` | Open the terminal manual in the best available pager |
| `help config <keyword>` | Jump directly to a section matching the keyword |
| `help config --html` | Open the documentation site in the default browser |
| `help config --man` | Open the compiled man page via `man -l` |
| `help config <keyword> --man` | Open the man page jumping to the nearest match |
| `repo-open` | Open this repo's web page in the browser (deep-links to the current branch and sub-directory) |

The pager falls back through: **ov** → **bat** → **man -l** → **less** → **cat**.

> **Note:** `fish-config` (hyphen) is this configuration's man page. `fish_config` (underscore) is fish's built-in browser-based configuration tool — a completely separate command. Don't mix them up.

---

## Installation

This config is managed as a Git repository. To use it on a new machine:

```fish
# Back up any existing config
mv ~/.config/fish ~/.config/fish.bak

# Clone this repo
git clone https://git.rootiest.dev/rootiest/fish-config.git ~/.config/fish
```

Then open a new Fish shell — Fisher will be installed automatically on first launch and the Catppuccin Mocha theme will be applied. All plugin functionality is bundled directly with this config and requires no additional installation.

A [chezmoi](https://www.chezmoi.io/) dotfile manager is also configured — secrets are kept in a private overlay directory (see [Personalization](#personalization)) and excluded from version control.

> [!IMPORTANT]
> `config.fish` ends with a `return` sentinel guard. Any lines appended **after** it by a tool's setup command will silently have no effect. Many tools (starship, zoxide, mise, etc.) offer a setup command that appends an `init | source` line to your `config.fish` — all integrations are managed through `conf.d/` files instead. If you add a new tool and its shell integration appears to do nothing, check whether its setup command appended an init line to the bottom of `config.fish` and create a `conf.d/<tool>.fish` file for it instead.

### Updating the Config

Pull the latest changes from upstream without needing a configured git remote:

| Command | Description |
|---|---|
| `config-update` | Fetch and apply the latest commits from upstream |
| `config-update --dry-run` | Preview available changes without applying them |
| `config-update --force` | Stash local changes, pull, then restore the stash |

---

## Personalization

Sensitive credentials and machine-specific paths are kept out of version control via a private overlay directory. The path defaults to `~/.config/.user-dots/fish/` but can be changed by setting a universal variable:

```fish
set -U __fish_user_dots_path /path/to/your/dots/fish
```

`config.fish` sources `local.fish` from that directory. `local.fish` is responsible for sourcing its own `secrets.fish` companion:

```
$__fish_user_dots_path/
├── secrets.fish   # API keys, tokens, passwords, personal identifiers
└── local.fish     # Machine-specific paths, env vars, and sourcing secrets
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

`config.fish` sources only `local.fish` with an existence check so the public config works cleanly on any machine without the private repo. `local.fish` is responsible for sourcing its own `secrets.fish`:

```fish
# config.fish resolves the path, then sources local.fish
set -q __fish_user_dots_path
    or set -l __fish_user_dots_path "$XDG_CONFIG_HOME/.user-dots/fish"
test -f "$__fish_user_dots_path/local.fish"
    and source "$__fish_user_dots_path/local.fish"
```

For convenience, a git-ignored `user-dots` symlink in the fish config directory is pointed at `$__fish_user_dots_path` on startup, so the overlay can be browsed from `~/.config/fish/`. It is recreated if missing and repointed if the path variable changes. Creation is a C2 startup side-effect (`__fish_config_op_autoexec`); it only ever manages a symlink and never clobbers a real file or directory at that path.

To opt out, set `__fish_user_dots_symlink` to a falsy value (or toggle **Dots link** off on the **Paths** page of `config-settings`). Disabling it stops the symlink being generated and removes any existing one immediately — honoured regardless of the C2 master switch.

`fish_variables` (which fish auto-manages and may contain universal variable state) is excluded from this repo via `.gitignore`.

---

## Minimal Mode

Everything opinionated in this config — command shadows, startup side-effects, key and environment overrides, terminal integrations, logging, and the first-run greeting — is active by default but can be switched off.

> **The easy way — `config-settings`:** Run `config-settings` for an interactive TUI that manages settings across four pages — **Universal** and **Session** (the opinionated category toggles below, persistent or per-shell), **Sponge** (history-scrubbing: delay, exit codes, purge-on-exit, and extra sensitive variable names), and **Paths** (scrollback log dir, max files, and the user-dots path) — without typing a single variable name. Navigate with the arrow keys (or `h`/`j`/`k`/`l`); toggle rows step OFF ← DEFAULT → ON, value rows edit inline with `Enter` and clear with `←`. `Tab`/`Shift-Tab` cycle pages and `q` quits. Changes apply instantly. The panel auto-sizes to your terminal width (four tiers from 52- to 78-wide with a 6-column margin), centers itself horizontally, and redraws within ~0.3 s of a resize.

If you'd rather set them by hand, each category is controlled by a universal variable. Six category toggles and one master switch are available:

| Variable | Disables |
|---|---|
| `__fish_config_op_aliases` | Command shadows: `ls`→eza, `cat`→bat, `cd`→zoxide, `rm`→trash, `top`→btop, `edit`→multi-editor launcher, and friends; `grep`/`cp`/`mv`/`wget` flag injection |
| `__fish_config_op_autoexec` | Startup side-effects: Fisher bootstrap, theme apply, `paru`/`yay` wrapper generation, auto venv activation, WakaTime hook, auto-pull background fast-forward |
| `__fish_config_op_overrides` | Vi mode, `exit`→`smart_exit`, `$PAGER`/`$MANPAGER`/`$CDPATH`/`XDG`/`PATH`, bang-bang history expansion, autopair, puffer, Starship prompt, theme colors |
| `__fish_config_op_integrations` | Kitty/WezTerm window abbreviations, `done` notifications, `spwin`/`tab`/`split`, `hist`, `logs`, `upgrade`, WakaTime |
| `__fish_config_op_logging` | Scrollback capture on exit, tmux `pipe-pane` pane logging, zellij `dump-screen` capture on exit, `paru`/`yay` AUR log wrappers, Kitty watcher capture (sentinel-file coordinated) |
| `__fish_config_op_greeting` | Per-session `fish_greeting` (suppresses distro greetings such as CachyOS fastfetch by overriding with an empty function); first-run welcome banner |
| `__fish_config_opinionated` | Master switch — all six categories at once |

Set any of them to a falsy value (`0`, `false`, `no`, `off`, `n`) to disable; erase the variable to re-enable. An explicit per-category truthy value overrides a falsy master switch, so you can disable everything with `__fish_config_opinionated=0` and selectively re-enable individual categories:

```fish
# Plain shell: disable everything opinionated
set -U __fish_config_opinionated 0

# Or pick a single category, e.g. keep integrations but drop command shadows
set -U __fish_config_op_aliases off

# Minimal mode but keep the greeting (per-category overrides master)
set -U __fish_config_opinionated 0
set -U __fish_config_op_greeting 1

# Back to full flavor
set -Ue __fish_config_opinionated
set -Ue __fish_config_op_greeting
```

Command shadows react immediately; bindings, prompt, and abbreviations take effect in new shells. With aliases disabled, `rm` deletes permanently again instead of trashing. See `help config opinionated` for the full component list.

---

## Attribution

The core of the [Zoxide integration](https://fish.rootiest.fyi/02-path-setup/) in this repository was originally adapted from the [icezyclon/zoxide.fish](https://github.com/icezyclon/zoxide.fish) plugin (MIT Licensed) and has since been heavily customized for performance and Fish 4.x compatibility.

---

## License

Copyright (C) 2026 Rootiest

This project is licensed under the **GNU Affero General Public License v3.0 or later** (AGPLv3+).
See the [LICENSE](LICENSE) file for the full license text.
