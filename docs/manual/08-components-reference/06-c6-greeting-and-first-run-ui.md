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

