---
title: C3 — Key and Environment Overrides
---

These change fundamental shell behavior: how keys work, which pager opens,
and what the prompt looks like. Disabling __fish_config_op_overrides removes
all of them.

    Override                  What it replaces or sets
    ───────────────────────────────────────────────────────────────────────────
    Vi mode                   fish_vi_key_bindings replaces default Emacs mode
    PATH setup                Prepends custom bin directories to the PATH
    exit → smart_exit         exit wrapper that captures scrollback before closing
    PAGER=ov                  ov used by git, man, and all $PAGER-aware tools
    EDITOR=nvim               nvim fallback to vi for git commit, etc.
    GPG_TTY                   Sets GPG_TTY to current terminal tty
    MANPAGER=bat pipeline     man pages rendered with syntax highlighting
    CDPATH=. ~/projects ~     bare dir names resolve against ~/projects and ~
    Bang-bang system          ! and $ keys expand history; !^, !*, !-N, !?str?,
                              ^old^new abbreviations; six expand_bang_* helpers
    Autopair                  ( [ { " ' auto-close to (), [], {}, "", ''
    Puffer key intercepts     . ! $ * keys intercepted for smart expansion
    Starship prompt           fish_prompt replaced by Starship + OSC 133 markers
    Catppuccin colors         30+ fish_color_* variables set to Mocha palette
    FZF_DEFAULT_OPTS          FZF themed to Catppuccin Mocha colors
    Right prompt              fish_right_prompt: exit code (on failure) + dim timestamp; always rendered; Docker context added when starship+C3 active

The bang-bang system spans key_bindings.fish, abbr.fish, puffer.fish, and
six expand_bang_*.fish functions. All are gated together — disabling C3
removes the entire bang-expansion system at once.

When C3 is disabled, `exit` falls back to `builtin exit` with no scrollback
capture, no Kitty IPC, and no file I/O on exit. The scrollback capture block
is independently controlled by C5 (see below).

