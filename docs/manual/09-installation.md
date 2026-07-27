---
title: Installation
manTitle: 9. INSTALLATION
sidebar:
  order: 13
helpKeywords:
- installation
- install
---

This configuration is managed as a git repository. To deploy on a new machine:

    mv ~/.config/fish ~/.config/fish.bak   # back up any existing config
    git clone https://git.rootiest.dev/rootiest/fish-config.git ~/.config/fish

Then open a new Fish shell. Fisher installs automatically on first launch
and the Catppuccin Mocha theme is applied. All other plugin functionality is
bundled directly with this config and requires no additional installation.

## Return Sentinel

config.fish ends with a return sentinel guard. Any lines appended after it by
a tool's setup command (starship init fish | source, zoxide init fish | source,
etc.) will have no effect. All integrations are managed via conf.d/ files.

If a new tool's shell integration appears to do nothing, check whether its
setup command appended an init line below the sentinel and create a dedicated
`conf.d/<tool>.fish` instead.

## Updating

Pull the latest changes from the upstream repository without needing a
configured git remote:

    config-update              Fetch and apply the latest commits from upstream
    config-update --dry-run    Preview available changes without applying them
    config-update --force      Stash local changes, pull, then restore the stash

All git output is suppressed. Run exec fish after a successful update to reload.

---
