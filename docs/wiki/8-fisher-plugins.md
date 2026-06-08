# 8. FISHER PLUGINS

**Sections:** [Index](index.md) | [1. Configuration Variables](1-configuration-variables.md) | [2. Path Setup](2-path-setup.md) | [3. Key Bindings](3-key-bindings.md) | [4. Abbreviations](4-abbreviations.md) | [5. Functions Reference](5-functions-reference.md) | [6. Dependency Catalog](6-dependency-catalog.md) | [7. Customization](7-customization.md) | **8. Fisher Plugins** | [9. Viewing This Manual](9-viewing-this-manual.md)

---

Fisher is bootstrapped automatically on the **first interactive session** via
`conf.d/first_run.fish`. This also applies the Catppuccin Mocha theme and
prints a one-time welcome message. Subsequent sessions skip all first-run
logic with zero overhead.

To re-trigger first-run initialization (e.g., after a fresh install or for
testing), run:

    set -Ue __fish_config_first_run_complete

Then open a new shell.

The plugin list is maintained in fish_plugins at the config root.

    jorgebucaran/fisher           Plugin manager itself
    catppuccin/fish               Catppuccin Mocha color theme
    PatrickF1/fzf.fish            fzf integration for Fish
    franciscolourenco/done        Desktop notification when long commands finish
    jorgebucaran/autopair.fish    Auto-pair brackets and quotes
    meaningful-ooo/sponge         Remove failed commands from history
    nickeb96/puffer-fish          !! / !$ / ./ expansion

Run `fisher update` to update all plugins, or `fish-deps update` which
calls fisher update as its first step.

---
