# 7. CUSTOMIZATION

**Sections:** [Index](index.md) | [1. Configuration Variables](1-configuration-variables.md) | [2. Path Setup](2-path-setup.md) | [3. Key Bindings](3-key-bindings.md) | [4. Abbreviations](4-abbreviations.md) | [5. Functions Reference](5-functions-reference.md) | [6. Dependency Catalog](6-dependency-catalog.md) | **7. Customization** | [8. Fisher Plugins](8-fisher-plugins.md) | [9. Viewing This Manual](9-viewing-this-manual.md)

---

## Machine-local Configuration

Place machine-specific settings that should not be committed to git in:

    ~/.config/.user-dots/fish/local.fish

Typical uses: additional PATH entries, local aliases, hostname-specific env
vars, work-specific tool configs.

## Secrets and API Keys

    ~/.config/.user-dots/fish/secrets.fish

Store API tokens, GPG keys, private credentials here. This file is never
committed.

Both files are sourced at the end of config.fish on every interactive
session, so they can override anything set earlier.

## Overriding Configuration Variables

Any variable set in local.fish after the main config loads takes effect.
Example: to increase the scrollback history limit:

    # in local.fish
    set -gx SCROLLBACK_HISTORY_MAX_FILES 200

## Fish Universal Variables

Some settings (fzf colors, theme) are stored in fish_variables via
`set -U`. These are machine-local and git-ignored. Do not commit
fish_variables.

---
