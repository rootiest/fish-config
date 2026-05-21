# Fish Config Requirements

Non-standard applications required by this fish shell configuration.

## Terminal Emulators

| Tool | Description | Notes |
|------|-------------|-------|
| `kitty` | GPU-accelerated terminal emulator | Primary terminal; used heavily for tab/window management via `kitty @` |
| `wezterm` | Cross-platform GPU-accelerated terminal | Referenced as alternative |
| `konsole` | KDE terminal emulator | Used in `tab.fish` as fallback |

## File & Directory Tools

| Tool | Description | Notes |
|------|-------------|-------|
| `lsd` | `ls` replacement with icons and colors | Wraps `ls`, `l`, `ll`, `lt`, `lstree`, `lS`, `ltr` |
| `bat` | `cat` replacement with syntax highlighting | Wraps `cat` |
| `dust` | Disk usage analyzer (Rust) | Used in `du.fish` |
| `duf` | Disk usage/free utility | Used in `du.fish` |
| `dua` | Fast disk space analyzer | Used in `du.fish` |
| `trash` / `trash-cli` | Safe file deletion to trash | Wraps `rm` |

## Editors

| Tool | Description | Notes |
|------|-------------|-------|
| `nvim` | Neovim text editor | Primary editor; used in `edit`, `view`, `nlazyup`, `nvimup` |
| `kate` | KDE text editor | Abbreviation target |

## Git & Version Control

| Tool | Description | Notes |
|------|-------------|-------|
| `lazygit` | Terminal Git UI | Abbreviation `lg` |
| `gitui` | Fast terminal Git UI | `gitui.fish` wrapper |
| `clone-in-kitty` | Clone repos into a Kitty window | Used in `clone.fish`, `clonet.fish` |

## System & Process Monitoring

| Tool | Description | Notes |
|------|-------------|-------|
| `btop` | Modern resource monitor | Wraps `top` |
| `fastfetch` | System info display | `ffetch.fish`, `cffetch.fish` |
| `neofetch` | System info display (fallback) | Fallback in `ffetch.fish` |

## Package Management

| Tool | Description | Notes |
|------|-------------|-------|
| `paru` | AUR helper (Arch Linux) | Used in `install`, `search`, `upgrade`, `parur` |

## Navigation & Search

| Tool | Description | Notes |
|------|-------------|-------|
| `zoxide` | Smart `cd` with frecency | Initialized in `zoxide.fish` |
| `fzf` | Fuzzy finder | Used in `parur.fish` and elsewhere |
| `ripgrep` / `rg` | Fast line-oriented search | Wrapped in `rg.fish` |

## Shell Prompt & Theme

| Tool | Description | Notes |
|------|-------------|-------|
| `starship` | Cross-shell prompt | Initialized in `config.fish` |

## Terminal Multiplexers

| Tool | Description | Notes |
|------|-------------|-------|
| `zellij` | Terminal workspace/multiplexer | `zellij.fish` wrapper |

## Network & Remote

| Tool | Description | Notes |
|------|-------------|-------|
| `tailscale` | VPN client | `tailscale.fish`, `tailart.fish` |
| `curl` | HTTP/data transfer | Used in `bd-pull.fish` |

## Developer & Productivity Tools

| Tool | Description | Notes |
|------|-------------|-------|
| `chezmoi` | Dotfile manager | Numerous abbreviations |
| `llm` | CLI for LLM interaction | `llm.fish` wrapper |
| `cheat` | Cheatsheet viewer | `cheat.fish`, `cheat.conf.d` |
| `wakatime` | Developer time tracking | Initialized in `wakatime.fish` |
| `bd` / `beads` | Lightweight issue tracker | `bd-pull.fish`, abbreviations |
| `lazybeads` | Terminal UI for beads | Abbreviation target |
| `agy` | antigravity-cli AI assistant | `antigravity.fish` wrapper, abbreviations |
| `antigravity-ide` | antigravity-ide editor | `antigravity-ide.fish` wrapper, abbreviations |

## Container Tools

| Tool | Description | Notes |
|------|-------------|-------|
| `docker` | Container platform | `dops.fish`, abbreviations |
| `lazydocker` | Terminal Docker UI | `ld` function in `config.fish` |

## Command Replacements / Enhancements

| Tool | Description | Notes |
|------|-------------|-------|
| `most` | Advanced pager | Wraps `less` |
| `prettyping` | Pretty `ping` wrapper | Wraps `ping` |
| `sudo-rs` | Rust rewrite of sudo | Wraps `sudo` |

## Data & System Utilities

| Tool | Description | Notes |
|------|-------------|-------|
| `jq` | JSON processor | Used in `bd-pull.fish` |
| `wl-colorpicker-plasma` | Wayland color picker (KDE) | `get-color.fish` |

## Fish Shell Framework & Plugins

| Tool | Description | Notes |
|------|-------------|-------|
| `fisher` | Fish plugin manager | Manages plugins via `fish_plugins` |
| `catppuccin/fish` | Catppuccin theme for Fish | Listed in `fish_plugins` |
