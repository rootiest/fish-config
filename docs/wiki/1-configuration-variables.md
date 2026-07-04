# 1. CONFIGURATION VARIABLES

**Sections:** [Index](index.md) | **1. Configuration Variables** | [2. Path Setup](2-path-setup.md) | [3. Key Bindings](3-key-bindings.md) | [4. Abbreviations](4-abbreviations.md) | [5. Functions Reference](5-functions-reference.md) | [6. Dependency Catalog](6-dependency-catalog.md) | [7. Customization](7-customization.md) | [8. Fisher Plugins](8-fisher-plugins.md) | [9. Installation](9-installation.md) | [10. Personalization](10-personalization.md) | [11. Viewing This Manual](11-viewing-this-manual.md)

---

These variables are exported from config.fish on every interactive session.
Override them in local.fish (see Section 10, Personalization).

## Environment Directories (XDG)

    XDG_CONFIG_HOME    ~/.config
    XDG_CACHE_HOME     ~/.cache
    XDG_DATA_HOME      ~/.local/share
    XDG_STATE_HOME     ~/.local/state

Tools that respect XDG are directed to these paths rather than polluting $HOME.

## Tool Homes (XDG-compliant)

    CARGO_HOME         $XDG_DATA_HOME/cargo
    RUSTUP_HOME        $XDG_DATA_HOME/rustup
    GOPATH             $XDG_DATA_HOME/go
    BUN_INSTALL        $XDG_DATA_HOME/bun
    NPM_CONFIG_PREFIX  $XDG_DATA_HOME/npm-global
    GNUPGHOME          $XDG_CONFIG_HOME/gnupg
    WAKATIME_HOME      $XDG_CONFIG_HOME/wakatime

## Editor and Pager

    EDITOR      nvim (falls back to vi if nvim is absent)
    VISUAL      unset by default; set a GUI editor via local.fish (the edit
                function falls back to a GUI chain when VISUAL is empty)
    SUDO_EDITOR same as EDITOR
    PAGER       ov (falls back to less)

## Scrollback History

    __fish_scrollback_history_dir        (unset → ~/.terminal_history)
    __fish_scrollback_history_max_files  (unset → 100)
    SCROLLBACK_HISTORY_DIR        ~/.terminal_history    (exported mirror)
    SCROLLBACK_HISTORY_MAX_FILES  100                    (exported mirror)

The __fish_scrollback_history_* universal variables are the fish-style source
of truth — set them via `config-settings` → Paths, or `set -U` directly.
config.fish exports the SCROLLBACK_HISTORY_* mirrors from them, because the
POSIX wrapper scripts (paru/yay/tmux/zellij logging and _prune_terminal_logs)
read the exported names from the environment. When the __fish_ vars are unset,
the documented defaults are exported. config.fish deliberately does not create
a global source var, which would shadow the universal and stop live edits from
taking effect.

Scrollback logs accumulate in SCROLLBACK_HISTORY_DIR as timestamped files.
When the count exceeds SCROLLBACK_HISTORY_MAX_FILES the oldest are pruned
automatically on exit. Use `logs` to browse them interactively.

## Other

    GPG_TTY              $(tty)  — ensures GPG passphrase prompts work
    CLAUDE_CODE_NO_FLICKER  1    — suppress terminal flicker in Claude Code
    CDPATH               . ~/projects ~

Opinionated defaults (CDPATH, PAGER/MANPAGER, Vi mode, command shadows,
terminal integrations) can be switched off per category with universal
variables — see Section 7, "Opinionated Components (Minimal Mode)".

## Pager Hierarchy

$PAGER is set to ov when available, falling back to less. The less wrapper
function extends this into a full chain so anything that calls less directly
also benefits:

    $PAGER → ov → less → more → cat

When bat is installed, man pages are rendered with syntax highlighting:

    MANROFFOPT   -c
    MANPAGER     sh -c 'col -bx | bat -l man -p'

## Integrations

### Zoxide

cd, z, and cdi/zi are all mapped to zoxide-backed navigation. Tab completions
for cd and z blend standard directory entries (CWD and CDPATH) with frecency
results so both familiar and frequently-visited paths appear in one list.

### DirEnv

Automatically loads .envrc files on directory change. Takes priority over
the auto-venv logic — if a directory is managed by direnv, the auto-venv
activation is skipped entirely.

### Auto Python Venv

When entering a directory that contains a .venv/, the virtualenv is activated
automatically and deactivated when you leave the project tree.

### WakaTime

Every shell command is reported to WakaTime for time-tracking. Set
FISH_WAKATIME_DISABLED=1 to disable without removing the plugin.

### Tailscale

Full tab completion for the tailscale CLI is provided via conf.d/tailscale.fish.

### Done Notifications

Desktop notifications fire when a command takes longer than 10 seconds and
the terminal window is not focused. Configured via fish universal variables:

    __done_min_cmd_duration          10000 ms
    __done_notification_urgency_level  low

### Scrollback History

When running inside Kitty, closing a shell session via exit saves a timestamped
scrollback snapshot to SCROLLBACK_HISTORY_DIR. Files are named:

    scrollback_YYYY-MM-DD_HH-MM-SS.log

The paru and yay wrappers (auto-generated in ~/.local/bin/) run the command
inside a PTY via script(1) so download progress bars are preserved on screen,
then render the captured terminal animation down to a clean static log via
scripts/clean_progress_log.py (a small terminal-screen emulator that replays
cursor movements, collapses repainted progress frames to their final state,
and preserves ANSI color). If python3 is unavailable the wrapper falls back to
dropping only the script(1) header/footer. Output is saved to:

    paru_YYYY-MM-DD_HH-MM-SS.log
    yay_YYYY-MM-DD_HH-MM-SS.log

Before pruning, _scrollback_prune_junk silently removes empty files, files
with only a single meaningful line (e.g. bare [exited] captures), and Kitty
tab-rename prompt captures. Use exit --no-log (or exit -n) to skip capture.

---
