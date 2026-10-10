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
| `fzf` | Fuzzy finder; >= 0.48 for its key bindings (`fzf-update` installs the latest) |

## Recommended

| Tool | Description |
|---|---|
| `cargo` | Rust toolchain (via rustup); used by `fish-deps` to install Rust-based tools and to build fish from source. All paths are gated on `type -q cargo` and degrade gracefully. Building needs a C compiler to link; `fish-deps` offers to install one (`build-essential`, `base-devel` or `gcc`) the first time it is needed. |
| `starship` | Cross-shell prompt; loaded via `type -q starship` guard. Without it the Catppuccin nim-style fallback prompt activates. |
| `uv` | Python package and project manager (Astral); used by the fish-from-source build path in `fish-deps`, which has it run the build with Sphinx so fish's man pages are rendered. Any system Python 3 works; `uv` downloads one itself only when the system has none. All consumers degrade gracefully without it. |
| `direnv` | Per-directory environment loading; integration is fully guarded with `type -q direnv`. Without it the direnv hook is simply not loaded and auto-venv activates normally. |
| `paru` | AUR helper (Arch only; preferred); guarded throughout — non-Arch systems silently skip AUR-specific paths. `fish-deps` neither offers it nor reports it as missing unless `os-release` identifies an Arch-based system. |
| `yay` | AUR helper (Arch only; fallback to paru); same guards apply. |
| `eza` | Modern `ls` replacement |
| `zoxide` | Smart cd with frecency |
| `lsd` | `ls` replacement (fallback to `eza`) |
| `bat` | Syntax-highlighted `cat` |
| `ov` | Modern pager (replaces `less`); also backs the `logs` viewer. Not a Rust crate, despite the name collision with an unrelated `ov` crate on crates.io. Prefers `go install github.com/noborus/ov@latest` when `go` is available (always gets the latest release, and covers distros like Debian/Ubuntu that don't package `ov` in their base repos); falls back to the system PM (AUR on Arch) otherwise. When the system PM has no `ov` and Go is missing, `fish-deps` offers to install Go first and then runs `go install`; a system package method the PM's index does not carry is left out rather than offered only to fail. |
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
| `go` | Go toolchain; only used to install `ov` via `go install` (see below), which gets the latest release and doesn't depend on your distro packaging `ov`. `fish-deps` maps the package name per distro (`go` on Arch/Homebrew, `golang-go` on Debian/Ubuntu, `golang` on Fedora) and offers to install Go itself when `ov` needs it, even though this entry is in the Optional tier. A distro's Go may be older than `ov` asks for; from Go 1.21 on, it then fetches the newer toolchain it needs by itself. |
| `lazygit` | Terminal git UI; only referenced by the `lg` abbreviation. |
| `lazydocker` | Terminal docker UI; backs the `ld` wrapper. |
| `docker` | Container runtime; gates the Docker context indicator in the right prompt and backs the `ld` wrapper. Both consumers are guarded with `type -q docker` and degrade gracefully without it. Installing the daemon package does not enable/start the service — do that yourself if you want it running. |
| `yt-dlp` | Video/media downloader; backs the `yt-dlp` wrapper function. The wrapper falls back to the system `yt-dlp` and the rest of the config works without it. |
| `screen` | GNU screen; fallback backend for `jobrunner` when `tmux` is unavailable. |
| `marktext` | Markdown editor; backs the `md` wrapper, which is the only thing that references it. No distro packages it under a common name, so `fish-deps` offers the AUR package (`marktext-bin`) on Arch and otherwise installs upstream's AppImage to `~/.local/bin/marktext`. |
| `firejail` | Sandbox; needed only by `md --read-only`, which uses it to make MarkText unable to save over the file it opened. Every other `md` invocation works without it. |
| `win32yank.exe` | Clipboard bridge for WSL2; backs the `y`/`p`/`hist` clipboard fallback chain when neither `wl-copy`/`wl-paste` nor `xclip` are present. `fish-deps` only offers to install it when WSL2 is detected (`microsoft` in `/proc/sys/kernel/osrelease`), downloading the pinned, checksum-verified x86_64 release from GitHub to `~/.local/bin`. |

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
| `cargo` | Rust tools (`eza`, `lsd`, `bat`, `dust`, `ripgrep`, `trashy`, `zoxide`, `starship`) — always gets the latest crate version, built with `--locked` |
| `go install` | `ov` — preferred over the system PM when `go` is available; always gets the latest release |
| system PM | `paru` / `apt` / `brew` / `dnf` / etc. — for tools without a crate or `go install` path |
| `git clone` | `fzf` — installed from GitHub to `~/.fzf/` |
| `curl` | `starship` installer, `fisher` bootstrap, `uv` installer |

Every cargo install passes `--locked`, so a crate is built against the
dependency versions it was published with. Without it, cargo ignores the
crate's lockfile and takes the newest compatible release of everything; that
is what made `eza` fail to compile against a newer `palette`.

Build prerequisites are not catalog entries. `fish-deps` offers them on demand,
once a method you chose needs them, and remembers the answer for the rest of
the run:

| Need | Used for | Packages |
|---|---|---|
| C compiler (`cc`) | linking every `cargo install` | `build-essential` (apt), `base-devel` (pacman), `gcc` (dnf, yum, zypper) |
| Rust toolchain | cargo being a bare rustup shim | `rustup default stable` |
| `unzip` | the `wakatime-cli` release zip | `unzip` |
| Go | `go install` of `ov` | `golang-go` (apt), `golang` (dnf, yum), `go` (others) |

`unzip` is deliberately not a catalog tier: one integration's download needs
it, and a dependency that shows up in every `fish-deps` report for that is
noise. `_fish_deps_wakatime_binary` says plainly when it is missing.

Installer scripts (`rustup`, `uv`, `starship`, `lazydocker`) are downloaded
to a temporary file and run only after the download succeeds; they are never
streamed into `sh`. Downloaded binaries (`wakatime-cli`, `win32yank.exe`, the
MarkText AppImage) are checked against a SHA-256 digest before they are made
executable: the release's published checksum file for `wakatime-cli`, the
digest GitHub records for the MarkText asset, and a pinned digest for
`win32yank.exe`, whose upstream publishes none. A failed download or checksum
mismatch aborts that install and reports failure.

---
