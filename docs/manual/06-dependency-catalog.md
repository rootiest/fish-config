---
title: Dependency Catalog
manTitle: 6. DEPENDENCY CATALOG
sidebar:
  order: 10
helpKeywords:
- catalog
- deps-catalog
---

fish-deps manages these tools. Run `fish-deps` to check status, or
`fish-deps install` to install missing ones.

## Required

| Tool | Description |
|---|---|
| `fish` | Fish shell >= 4.0 |
| `fzf` | Fuzzy finder |

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
| `zoxide` | Smart cd with frecency |
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
