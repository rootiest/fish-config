# 2. PATH SETUP

**Sections:** [Index](index.md) | [1. Configuration Variables](1-configuration-variables.md) | **2. Path Setup** | [3. Key Bindings](3-key-bindings.md) | [4. Abbreviations](4-abbreviations.md) | [5. Functions Reference](5-functions-reference.md) | [6. Dependency Catalog](6-dependency-catalog.md) | [7. Customization](7-customization.md) | [8. Fisher Plugins](8-fisher-plugins.md) | [9. Viewing This Manual](9-viewing-this-manual.md) | [10. Installation](10-installation.md) | [11. Personalization](11-personalization.md)

---

Directories prepended to PATH in this order (first wins):

    ~/.local/bin              Standard user-local executables
    ~/Applications            User-installed standalone apps
    ~/scripts                 Personal shell scripts
    ~/bin                     Cargo binaries (appended — lowest priority)
    $BUN_INSTALL/bin          Bun runtime and global packages
    $NPM_CONFIG_PREFIX/bin    Global npm packages
    ~/.lmstudio/bin           LM Studio CLI
    ~/.resend/bin             Resend CLI
    ~/.fzf/bin                fzf binary (git-installed)

Cargo binaries are intentionally appended (lowest priority) to avoid
shadowing system-installed Rust tools.

---
