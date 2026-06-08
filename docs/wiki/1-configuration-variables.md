# 1. CONFIGURATION VARIABLES

**Sections:** [Index](index.md) | **1. Configuration Variables** | [2. Path Setup](2-path-setup.md) | [3. Key Bindings](3-key-bindings.md) | [4. Abbreviations](4-abbreviations.md) | [5. Functions Reference](5-functions-reference.md) | [6. Dependency Catalog](6-dependency-catalog.md) | [7. Customization](7-customization.md) | [8. Fisher Plugins](8-fisher-plugins.md) | [9. Viewing This Manual](9-viewing-this-manual.md)

---

These variables are exported from config.fish on every interactive session.
Override them in ~/.config/.user-dots/fish/local.fish.

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
    VISUAL      same as EDITOR
    SUDO_EDITOR same as EDITOR
    PAGER       ov (falls back to less)

## Scrollback History

    SCROLLBACK_HISTORY_DIR        ~/.terminal_history
    SCROLLBACK_HISTORY_MAX_FILES  100

Scrollback logs accumulate in SCROLLBACK_HISTORY_DIR as timestamped files.
When the count exceeds SCROLLBACK_HISTORY_MAX_FILES the oldest are pruned
automatically on exit. Use `logs` to browse them interactively.

## Other

    GPG_TTY              $(tty)  — ensures GPG passphrase prompts work
    CLAUDE_CODE_NO_FLICKER  1    — suppress terminal flicker in Claude Code
    CDPATH               . ~/projects ~

---
