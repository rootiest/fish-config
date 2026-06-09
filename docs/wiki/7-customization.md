# 7. CUSTOMIZATION

**Sections:** [Index](index.md) | [1. Configuration Variables](1-configuration-variables.md) | [2. Path Setup](2-path-setup.md) | [3. Key Bindings](3-key-bindings.md) | [4. Abbreviations](4-abbreviations.md) | [5. Functions Reference](5-functions-reference.md) | [6. Dependency Catalog](6-dependency-catalog.md) | **7. Customization** | [8. Fisher Plugins](8-fisher-plugins.md) | [9. Installation](9-installation.md) | [10. Personalization](10-personalization.md) | [11. Viewing This Manual](11-viewing-this-manual.md)

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

## Prompt and Theme

### Starship

The primary prompt is Starship, initialized by conf.d/starship.fish.
Configure it via ~/.config/starship.toml.

conf.d/starship.fish defines a fish_prompt wrapper that only activates when
starship is in PATH. It emits OSC 133;A (prompt start) immediately before
Starship renders and OSC 133;B (input start) immediately after, placing both
markers on the prompt line itself. This allows ov to use them as sticky
section headers when browsing scrollback logs. Without Starship, fish's
built-in prompt handles these markers automatically.

### FZF

FZF is themed to Catppuccin Mocha via FZF_DEFAULT_OPTS set in
integrations/fzf.fish. The colors applied:

    Background:   #1E1E2E (base)    #313244 (surface0)
    Foreground:   #CDD6F4 (text)
    Highlights:   #F38BA8 (red)     #CBA6F7 (mauve)    #B4BEFE (lavender)

To customize, override FZF_DEFAULT_OPTS in local.fish.

### Catppuccin Mocha Syntax Highlighting

The Catppuccin Mocha theme ships with this config in themes/ and is applied
on first run via `conf.d/first_run.fish`. Colors are stored in fish_variables
(universal). To switch variants, install a different theme from themes/:

    fish_config theme save "Catppuccin Latte"

---
