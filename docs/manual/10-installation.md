---
title: Installation
manTitle: 10. INSTALLATION
sidebar:
  order: 14
helpKeywords:
- installation
- install
- os
- operating system
- compatibility
- linux
- macos
- windows
- wsl
---

This configuration is managed as a git repository. To deploy on a new machine:

    mv ~/.config/fish ~/.config/fish.bak   # back up any existing config
    git clone https://git.rootiest.dev/rootiest/fish-config.git ~/.config/fish

Then open a new Fish shell. Fisher installs automatically on first launch
and the Catppuccin Mocha theme is applied. All other plugin functionality is
bundled directly with this config and requires no additional installation.

## OS Compatibility

This is a **Linux-only** configuration. It is developed and tested on an
Arch Linux system; `fish-deps` also detects `apt`, `dnf`, `zypper`, and
`yum` for broader distro support, but coverage outside Arch is thinner.

IMPORTANT: A number of functions call Linux-specific subsystems directly, with
no fallback:
- `systemd-inhibit` (`wake-lock`)
- `zramctl` / `swapon` (`swapstat`)
- `sbctl` and UEFI Secure Boot state (`sbver`)
- GNU coreutils flags such as `stat -c` and `numfmt` (`sudo-toggle`,
  `dng2avif`), which differ or don't exist under a BSD userland

Clipboard access (`y`, `p`, `paste`, `hist`) is the exception: it falls back
through `wl-copy`/`wl-paste` (Wayland), `xclip` (X11), and `win32yank.exe`
(WSL2), so it works on all three. There is still no `pbcopy`/`pbpaste`
fallback for macOS.

**macOS** is not supported. `_fish_deps_detect_pm` does check for `brew`, but
that alone does not make the functions above work — they have no macOS
equivalent path today.

**Windows** is not supported. Fish itself has no native Windows build;
upstream's own "Windows" install docs are Cygwin/WSL workarounds, not a real
port. This config is not tested under WSL either. WSL2 runs a real Linux
kernel and can run `systemd`, so basic shell use may work; `zramctl`,
`sbctl`, and Secure Boot state are still meaningless inside a VM, but
clipboard integration works via `win32yank.exe` (see above) once it's
installed on the Windows side and reachable through WSL interop.

**Assumed present on any Linux system this runs on:** `git`, `gpg`, `tar`,
and GNU coreutils (for `stat`, `date`, `numfmt`). These are not tracked by
`fish-deps` — see the [Dependency Catalog](/06-dependency-catalog/) — because
they are base-system utilities, not opt-in software with an install journey
to manage. A system missing any of them is missing basic Linux tooling, not
a `fish-deps` gap.

## Return Sentinel

`config.fish` ends with a return sentinel guard. Any lines appended after it by
a tool's setup command (`starship init fish | source`, `zoxide init fish | source`,
etc.) will have no effect. All integrations are managed via `conf.d/` files.

If a new tool's shell integration appears to do nothing, check whether its
setup command appended an init line below the sentinel and create a dedicated
`conf.d/<tool>.fish` instead.

## Updating

Pull the latest changes from the upstream repository without needing a
configured git remote:

- `config-update` — Fetch and apply the latest commits from upstream
- `config-update --dry-run` — Preview available changes without applying them
- `config-update --force` — Stash local changes, pull, then restore the stash

All git output is suppressed. Run `exec fish` after a successful update to reload.

---
