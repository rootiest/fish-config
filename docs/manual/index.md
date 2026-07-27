---
title: Fish Shell Configuration
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

- Drop-in replacements for common Unix tools (ls, cat, rm, du, ping, less)
- Deep Kitty and WezTerm terminal integration: tab/window/pane management from
  the command line
- Optional session logging: terminal scrollback, tmux/zellij panes, and
  paru/yay output captured to ~/.terminal_history (off by default; see below)
- Automatic Python virtualenv activation on directory change
- Cross-platform package management via pkg and fish-deps
- AI scaffolding helpers for Claude Code and Antigravity
- Catppuccin Mocha color theme throughout

<LinkButton href="/09-installation/">Install now</LinkButton>
<LinkButton href="/reference/" variant="secondary">Function reference</LinkButton>

CAUTION: **SESSION LOGGING IS OPT-IN**  
Once enabled, this configuration *can* silently record terminal output to
`~/.terminal_history`: Kitty scrollback on window close, live tmux pane
streams, zellij pane snapshots on exit, and full paru/yay output. These logs
can contain command output, file contents, and secrets printed to the
terminal. Nothing leaves your machine, but the files persist locally. Logging
is off unless you turn it on.
- Enable all logging with: `set -U __fish_config_op_logging on`
- Prefer a menu? Run the interactive picker: `config-settings`
- Turn it back off with: `set -U __fish_config_op_logging off` (or erase the variable)
- See [C5 — Logging and Capture](/07-customization/#c5-logging-and-capture) for the full breakdown.

The configuration uses a structured file tree:

    ~/.config/fish/
    ├── config.fish                 Main entry point; sets env vars and PATH
    ├── conf.d/
    │   ├── abbr.fish               All abbreviations
    │   ├── autopair.fish           Auto-pair brackets and quotes
    │   ├── cheat.fish              cheat.sh tab completions
    │   ├── done.fish               Desktop notifications for long commands
    │   ├── first_run.fish          One-time init: Fisher bootstrap, theme
    │   ├── key_bindings.fish       Custom key bindings and Vi mode
    │   ├── logging-events.fish     C5 event handlers; syncs logging state
    │   ├── kitty-watcher-reminder.fish  C5 per-session Kitty watcher reminder
    │   ├── paru-wrapper.fish       Auto-generates paru logging wrapper
    │   ├── puffer.fish             !! / !$ / ./ expansion
    │   ├── tmux-logging.fish       C5 starts tmux pipe-pane capture
    │   ├── zellij-logging.fish     C5 fish_exit handler for zellij
    │   ├── sponge_privacy.fish     Sponge privacy patterns
    │   ├── starship.fish           fish_prompt shell-integration markers
    │   ├── tailscale.fish          Tailscale CLI tab completions
    │   ├── theme.fish              Catppuccin syntax highlight colors
    │   ├── tricks.fish             PATH, bang-bang helpers, bat man pages
    │   ├── wakatime.fish           WakaTime shell hook
    │   ├── yay-wrapper.fish        Auto-generates yay logging wrapper
    │   └── zoxide.fish             Zoxide z/zi integration; overrides cd
    ├── functions/                  Custom functions, one per file
    ├── completions/                Tab completion scripts
    ├── integrations/
    │   └── fzf.fish                FZF Catppuccin theme and key bindings
    ├── scripts/
    │   ├── clean_progress_log.py   Strips typescript animations for clean logs
    │   └── agents-tools/           AGENTS.md scripts and git hooks
    └── docs/                       Offline documentation and man page
        ├── fish-config.md          Primary source manual
        ├── fish-config.1           Compiled man page (auto-generated)
        ├── fish-config.index       Section index for help config
        ├── html/                   Chunked HTML docs (auto-generated)
        └── wiki/                   Markdown wiki (auto-generated)

---
