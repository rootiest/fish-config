---
title: Dependency Catalog
manTitle: 6. DEPENDENCY CATALOG
sidebar:
  order: 10
helpKeywords:
- catalog
- deps-catalog
---

fish-deps manages these tools. Run `fish-deps` to check status,
`fish-deps install` to install missing Required/Recommended ones, or add
`--optional`, `--terminals`, or `--all` to also include the Optional and/or
Terminal Emulators tiers.

## Required

| Tool | Description |
|---|---|
| `fish` | Fish shell >= 4.0 |
| `fzf` | Fuzzy finder |

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
| `zoxide` | Smart cd with frecency |
| `lsd` | `ls` replacement (fallback to `eza`) |
| `bat` | Syntax-highlighted `cat` |
| `ov` | Modern pager (replaces `less`); also backs the `logs` viewer. Not a Rust crate, despite the name collision with an unrelated `ov` crate on crates.io. Prefers `go install github.com/noborus/ov@latest` when `go` is available (always gets the latest release, and covers distros like Debian/Ubuntu that don't package `ov` in their base repos); falls back to the system PM (AUR on Arch) otherwise. |
| `ripgrep` | Fast line search |
| `trash` | Safe delete (`trash-cli`); backs the `rm` and `scrub` wrappers. |
| `python3` | Standalone interpreter — used by the `paru`/`yay` log cleaner. Note: `uv` does not provide `python3` on PATH, and Arch's base does not include it, so it is listed separately. All consumers degrade gracefully without it. |

## Optional

Single-purpose tools that back one wrapper function (or less) and only
matter if you already use that specific tool. Skipped by
`fish-deps install`/`sync` unless you pass `--optional`.

| Tool | Description |
|---|---|
| `btop` | Modern resource monitor; backs the `top` wrapper (falls back to system `top`). |
| `dust` | Disk usage tree (Rust); one of two backends for the `du` wrapper (falls back to system `du`). |
| `duf` | Disk usage/free overview; the other backend for the `du` wrapper (falls back to system `du`). |
| `prettyping` | Colorized ping wrapper; backs the `ping` wrapper (falls back to system `ping`). |
| `go` | Go toolchain; only used to install `ov` via `go install` (see below), which gets the latest release and doesn't depend on your distro packaging `ov`. Package name varies by distro (`go` on Arch/Homebrew, `golang`/`golang-go` on Debian/Fedora) — install manually if the listed package name doesn't resolve on your system. |
| `lazygit` | Terminal git UI; only referenced by the `lg` abbreviation. |
| `lazydocker` | Terminal docker UI; backs the `ld` wrapper. |
| `docker` | Container runtime; gates the Docker context indicator in the right prompt and backs the `ld` wrapper. Both consumers are guarded with `type -q docker` and degrade gracefully without it. Installing the daemon package does not enable/start the service — do that yourself if you want it running. |
| `yt-dlp` | Video/media downloader; backs the `yt-dlp` wrapper function. The wrapper falls back to the system `yt-dlp` and the rest of the config works without it. |
| `screen` | GNU screen; fallback backend for `jobrunner` when `tmux` is unavailable. |

## Terminal Emulators

GPU-accelerated terminal emulators. Only one is ever relevant to a given
user — the one matching `$TERM` — so neither is installed by default.
Skipped by `fish-deps install`/`sync` unless you pass `--terminals` (or
`--all`).

| Tool | Description |
|---|---|
| `kitty` | GPU-accelerated terminal; unlocks kitty-specific abbreviations and `--hyperlink-format=kitty` in the `rg` wrapper when `$TERM = xterm-kitty`. |
| `wezterm` | GPU-accelerated terminal; unlocks WezTerm-specific abbreviations when it's the active terminal. |

## Integrations

Opt-in third-party services that require their own account/setup.

| Tool | Description |
|---|---|
| `wakatime` | Developer time tracking |
| `tailscale` | Mesh VPN client |

## Install Methods

The install priority for each tool:

| Method | Packages |
|---|---|
| `cargo` | Rust tools (`eza`, `lsd`, `bat`, `dust`, `ripgrep`, `trashy`, `zoxide`, `starship`) — always gets the latest crate version |
| `go install` | `ov` — preferred over the system PM when `go` is available; always gets the latest release |
| system PM | `paru` / `apt` / `brew` / `dnf` / etc. — for tools without a crate or `go install` path |
| `git clone` | `fzf` — installed from GitHub to `~/.fzf/` |
| `curl` | `starship` installer, `fisher` bootstrap, `uv` installer |

---
