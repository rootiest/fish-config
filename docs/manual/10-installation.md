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

This configuration requires **Fish 4.x or newer**; check with `fish --version`.
A distro-packaged Fish 3.x is too old. The Fish Version Requirement section of
the Troubleshooting chapter lists upgrade steps by distribution, and `fish-deps`
reports an outdated Fish.

This configuration is managed as a git repository. To deploy on a new machine:

    mv ~/.config/fish ~/.config/fish.bak   # back up any existing config
    git clone https://git.rootiest.dev/rootiest/fish-config.git ~/.config/fish

Then open a new Fish shell. Fisher installs automatically on first launch
and the Catppuccin Mocha theme is applied. All other plugin functionality is
bundled directly with this config and requires no additional installation.

## Installing the Tools

The shell itself needs nothing more, but much of what makes it useful is a
set of external tools: `starship`, `fzf`, `zoxide`, `eza`, `bat`, `ripgrep`
and others. Every one degrades gracefully when absent, and `fish-deps`
installs them for you. From the first shell:

    fish-deps            # report what is installed and what is missing
    fish-deps install    # install what is missing, one prompt per tool

`fish-deps install` walks the [Dependency Catalog](/06-dependency-catalog/)
and, for each missing tool, asks `Install <tool>? [Y/n/q]`. Enter or `y`
installs it, `n` skips that tool, and `q` (or Ctrl+C, or Ctrl+D) stops the
whole run, so nothing further is offered. When a tool can be installed more
than one way, it lists the methods and lets you pick; Enter takes the first,
which is the preferred one. Nothing is installed without your answer, and
`sudo` asks for its own password where the system package manager needs it.

Beyond the individual installs it takes care of the things a fresh server
tends to lack, but only when a method you chose needs them:

- A C compiler (`build-essential`, `base-devel` or `gcc`), before any Rust
  tool is built with cargo.
- A default Rust toolchain, when `cargo` is only a rustup shim.
- `unzip`, before the `wakatime-cli` download.
- Go, before installing `ov` on a distro that does not package it.

Newly installed tools are put on the current shell's `PATH` right away, so
there is no restart between steps; fish itself is the exception, and needs a
new shell once it has been upgraded. The Optional and Terminal Emulator tiers
are skipped unless you add `--optional`, `--terminals` or `--all`.

TIP: `fish-deps sync` installs what is missing and then updates everything
installed. The full subcommand reference, including exit codes, is on the
[fish-deps function page](/reference/dependency-management/fish-deps/), and
[Missing Dependencies](/12-troubleshooting/#missing-dependencies) covers what
to do when an install step fails.

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

Clipboard access (`y`, `p`, `hist`) is the exception: it falls back
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
