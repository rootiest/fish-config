# 9. INSTALLATION

**Sections:** [Index](index.md) | [1. Configuration Variables](1-configuration-variables.md) | [2. Path Setup](2-path-setup.md) | [3. Key Bindings](3-key-bindings.md) | [4. Abbreviations](4-abbreviations.md) | [5. Functions Reference](5-functions-reference.md) | [6. Dependency Catalog](6-dependency-catalog.md) | [7. Customization](7-customization.md) | [8. Fisher Plugins](8-fisher-plugins.md) | **9. Installation** | [10. Personalization](10-personalization.md) | [11. Viewing This Manual](11-viewing-this-manual.md)

---

This configuration is managed as a git repository. To deploy on a new machine:

    mv ~/.config/fish ~/.config/fish.bak   # back up any existing config
    git clone https://git.rootiest.dev/rootiest/fish-config.git ~/.config/fish

Then open a new Fish shell. Fisher and all plugins install automatically on
first launch and the Catppuccin Mocha theme is applied.

## Return Sentinel

config.fish ends with a return sentinel guard. Any lines appended after it by
a tool's setup command (starship init fish | source, zoxide init fish | source,
etc.) will have no effect. All integrations are managed via conf.d/ files.

If a new tool's shell integration appears to do nothing, check whether its
setup command appended an init line below the sentinel and create a dedicated
conf.d/<tool>.fish instead.

## Updating

Pull the latest changes from the upstream repository without needing a
configured git remote:

    config-update              Fetch and apply the latest commits from upstream
    config-update --dry-run    Preview available changes without applying them
    config-update --force      Stash local changes, pull, then restore the stash

The remote URL (https://git.rootiest.dev/rootiest/fish-config.git) is
hard-coded, so this works on a fresh clone with no origin configured. All
git output is suppressed. Run exec fish after a successful update to reload.

---
