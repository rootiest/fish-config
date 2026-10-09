---
title: Rootiest Fish Configuration
description: Reference manual for the rootiest fish configuration.
manTitle: DESCRIPTION
sidebar:
  order: 3
helpKeywords:
- description
- autopair
- puffer
- puffer-fish
- logging-events
---

A production-grade Fish shell configuration targeting Fish 4.x. It provides:

- Drop-in replacements for common Unix tools (`ls`, `cat`, `rm`, `du`, `ping`, `less`)
- Deep Kitty and WezTerm terminal integration: tab/window/pane management from
  the command line
- Optional session logging: terminal scrollback, tmux/zellij panes, and
  paru/yay output captured to `~/.terminal_history` (off by default; see [C5 Logging](/08-components-reference/05-c5-logging-and-capture/))
- Automatic Python virtualenv activation on directory change
- Cross-platform package management via pkg and fish-deps
- AI scaffolding helpers for Claude Code and Antigravity
- Catppuccin Mocha color theme throughout

<LinkButton href="/10-installation/" icon="cloud-download" style="font-size: 1.25rem; padding: 1rem 1.5rem; margin-right: 1rem;">Install now</LinkButton>
<LinkButton href="/reference/" variant="secondary" style="font-size: 1.125rem; padding: 0.85rem 1.25rem;">Functions</LinkButton>
<LinkButton href="/08-components-reference/" variant="secondary" style="font-size: 1.125rem; padding: 0.85rem 1.25rem;">Components</LinkButton>

The configuration uses a structured file tree:

    ~/.config/fish/
    ├── config.fish                 Main entry point; sets env vars and PATH
    ├── conf.d/                     Snippets sourced at startup
    │   ├── __fish_config_op_registry.fish  Generated component registry
    │   ├── abbr.fish               All abbreviations
    │   ├── auto-pull.fish          Background git pulls for opted-in repos
    │   ├── autopair.fish           Auto-pair brackets and quotes
    │   ├── bash_expands.fish       Bash-style history expansion
    │   ├── done.fish               Desktop notifications for long commands
    │   ├── first_run.fish          One-time init: Fisher bootstrap, theme
    │   ├── fzf.fish                fzf key bindings and pickers
    │   ├── help.fish               help command for config topics
    │   ├── key_bindings.fish       Custom key bindings and Vi mode
    │   ├── kitty-watcher-reminder.fish  C5 per-session Kitty watcher reminder
    │   ├── logging-events.fish     C5 event handlers; syncs logging state
    │   ├── pkg-wrappers.fish       Auto-generates paru/yay logging wrappers
    │   ├── puffer.fish             !! / !$ / ./ expansion
    │   ├── sponge_privacy.fish     Sponge privacy patterns
    │   ├── starship.fish           fish_prompt shell-integration markers
    │   ├── theme.fish              Catppuccin syntax highlight colors
    │   ├── tmux-logging.fish       C5 starts tmux pipe-pane capture
    │   ├── tricks.fish             PATH, bang-bang helpers, bat man pages
    │   ├── wakatime.fish           WakaTime shell hook
    │   ├── zellij-logging.fish     C5 fish_exit handler for zellij
    │   └── zoxide.fish             Zoxide z/zi integration; overrides cd
    ├── functions/                  Custom functions, one per file
    ├── completions/                Tab completion scripts, autoloaded on demand
    ├── scripts/                    Helper scripts and tools
    │   ├── agents-tools/           AGENTS.md git hooks and version-bump
    │   ├── claude-shell-prefix     Strips telemetry opt-outs for claude
    │   ├── clean_progress_log.py   Strips typescript animations for clean logs
    │   ├── cli-agent.md            System prompt for the terminal assistant
    │   ├── config-settings-tui.py  curses front-end for config-settings
    │   ├── kitty-fish-config-watcher.py  Kitty logging watcher
    │   └── sync-labels.py          Syncs Gitea labels to the GitHub mirror
    ├── data/                       gi templates, session-env catalog, word lists
    ├── templates/                  Function templates to copy and adapt
    │   └── allow-telemetry.fish    Per-command telemetry opt-out wrapper
    ├── themes/                     Catppuccin color themes
    │   ├── catppuccin-frappe.theme     Frappé (medium dark)
    │   ├── catppuccin-latte.theme      Latte (light)
    │   ├── catppuccin-macchiato.theme  Macchiato (dark)
    │   └── catppuccin-mocha.theme      Mocha (darkest), the default
    ├── tests/                      Test suite: fish tests/run-tests.fish
    └── docs/                       Offline documentation and man page
        ├── fish-config.md          Generated manual
        ├── fish-config.1           Compiled man page (auto-generated)
        ├── fish-config.index       Section index for help config
        ├── manual/                 Manual source, one file per chapter
        └── site/                   Source for this documentation site

---
