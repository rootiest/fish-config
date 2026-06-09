# Fish Shell Configuration

A feature-rich Fish shell configuration for CachyOS (Arch Linux),
built around a Catppuccin Mocha aesthetic with a curated set of modern
CLI tool integrations, smart shell functions, and a heavily customized
abbreviation system for keyboard-driven workflows.

## Table of Contents

- [Overview](#overview)
- [Documentation](#documentation)
- [Installation](#installation)
- [Personalization](#personalization)
- [Attribution](#attribution)
- [License](#license)

---

## Overview

This config layers on top of the CachyOS base Fish configuration and adds:

- **Catppuccin Mocha** theming throughout (prompt, FZF, syntax highlighting)
- **Starship** prompt with VI key bindings
- **Fisher** plugin manager bootstrapped automatically; manages `sponge` (failed-command history filter); FZF bindings, Catppuccin theme, done, autopair, and puffer-fish are bundled directly with the config as customized versions
- **Smart CLI wrappers** that prefer modern tools (`eza`, `bat`, `btop`, `dust`, `prettyping`) with graceful fallbacks
- **Auto Python venv** activation on directory change (direnv-aware)
- **Kitty terminal** deep integration for splits, tabs, and SSH
- **AI workflow** helpers for Claude and Antigravity session management
- **WakaTime** shell activity tracking

---

## Documentation

### [📖 Full Documentation Wiki](docs/wiki/index.md)

A multi-page Markdown wiki auto-generated from the single source file `docs/fish-config.md`
on every push to `main`. It covers configuration variables, key bindings, abbreviations,
all functions, the dependency catalog, customization, and more.

To browse the docs from the terminal:

| Command | Description |
|---|---|
| `help config` | Open the terminal manual in the best available pager |
| `help config <keyword>` | Jump directly to a section matching the keyword |
| `help config --html` | Open the pre-built HTML docs in the default browser |
| `help config --man` | Open the compiled man page via `man -l` |

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

A [chezmoi](https://www.chezmoi.io/) dotfile manager is also configured — secrets are sourced from `~/.config/.user-dots/fish/secrets.fish` and excluded from version control.

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

The core of the [Zoxide integration](docs/wiki/2-path-setup.md) in this repository was originally adapted from the [icezyclon/zoxide.fish](https://github.com/icezyclon/zoxide.fish) plugin (MIT Licensed) and has since been heavily customized for performance and Fish 4.x compatibility.

---

## License

Copyright (C) 2026 Rootiest

This project is licensed under the **GNU Affero General Public License v3.0 or later** (AGPLv3+).
See the [LICENSE](LICENSE) file for the full license text.
