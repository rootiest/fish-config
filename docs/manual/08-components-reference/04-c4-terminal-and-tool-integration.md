---
title: C4 — Terminal and Tool Integration
---

These features couple the shell to specific external tools. Disabling
__fish_config_op_integrations disables all of them.

    Component                  Requires
    ───────────────────────────────────────────────────────────────────────────
    ~60 Kitty/WezTerm abbrs    Active Kitty or WezTerm session
      (:w, :wv, :wh, :t, etc.)
    Done desktop notifications  Graphical desktop with a notification daemon
    spwin                      Kitty or WezTerm
    tab                        Kitty, WezTerm, or Konsole
    split                      Kitty or WezTerm
    hist                       fzf + wl-copy (Wayland clipboard)
    logs                       fzf + ov; reads from ~/.terminal_history/
    upgrade                    paru or yay (Arch Linux only)
    WakaTime hook              wakatime CLI and a configured API key

Disabled integration commands (spwin, tab, split, hist, logs, upgrade) print
a colored error to stderr naming the variable that disabled them rather than
silently failing.

