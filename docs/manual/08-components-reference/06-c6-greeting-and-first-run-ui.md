---
title: C6 — Greeting and First-Run UI
---

    Component                  What it shows
    ───────────────────────────────────────────────────────────────────────────
    First-run welcome banner   One-time message on first interactive session
    fish_greeting override     Empty function defined late in config.fish to
                               suppress distro greetings (e.g. CachyOS sets
                               fish_greeting to fastfetch by default)

When C6 is disabled, no greeting is printed by this config. Any greeting
set by the distro or other configs runs normally — this config simply does
not override it.

## Sub-categories

`__fish_config_op_greeting` sub-divides into two sub-categories, each
with its own `__fish_config_op_greeting_<slug>` toggle:

## first-run

The first-run welcome banner.

## greeting-message

The per-session `fish_greeting` override.

