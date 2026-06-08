# Fish Shell Configuration

A production-grade Fish shell configuration targeting Fish 4.x. It provides:

- Drop-in replacements for common Unix tools (ls, cat, rm, du, ping, less)
- Deep Kitty and WezTerm terminal integration: tab/window/pane management from
  the command line
- Scrollback history snapshots saved to ~/.terminal_history on session exit
- Automatic Python virtualenv activation on directory change
- Cross-platform package management via pkg and fish-deps
- AI session helpers for Claude Code and Antigravity
- Catppuccin Mocha color theme throughout

The configuration is split across:

    config.fish          Main entry point; sets env vars and PATH
    conf.d/              Auto-sourced fragments: keybindings, abbreviations,
                         theme, starship, zoxide, wakatime
    functions/           One function per file, autoloaded by Fish
    completions/         Tab completion scripts
    integrations/        FZF Catppuccin theme and bindings
    docs/                This offline documentation and compiled man page

---

---

## Table of Contents

- [1. Configuration Variables](1-configuration-variables.md)
- [2. Path Setup](2-path-setup.md)
- [3. Key Bindings](3-key-bindings.md)
- [4. Abbreviations](4-abbreviations.md)
- [5. Functions Reference](5-functions-reference.md)
- [6. Dependency Catalog](6-dependency-catalog.md)
- [7. Customization](7-customization.md)
- [8. Fisher Plugins](8-fisher-plugins.md)
- [9. Viewing This Manual](9-viewing-this-manual.md)
