---
title: C1 — Command Shadows
---

Disabling __fish_config_op_aliases restores standard system behavior for
all of these commands.

    Command / Alias    Active behavior                       Disabled fallback
    ───────────────────────────────────────────────────────────────────────────
    ls                 eza -l -a --icons --hyperlink          system ls
    cat                bat syntax-highlighted; dirs → ls      /usr/bin/cat
    cd                 zoxide frecency-based navigation        fish builtin cd
    rm                 moves files to trash (recoverable)     command rm (permanent)
    less               $PAGER → ov → less → more → cat       system less
    du                 duf (disk overview) or dust (dir tree)  system du
    top                btop resource monitor                  system top
    ping               prettyping --nolegend animation        system ping
    ssh                kitten ssh in Kitty terminal           system ssh
    rg                 rg --hyperlink-format=kitty            system rg
    mkdir              verbose path-tree display on creation  mkdir -p silently
    bash               XDG bashrc + $SHELL reset on exit      system bash
    history            timestamps prepended to every entry    fish builtin history
    cp / mv            forced -i confirmation prompt          cp / mv unmodified
    wget               forced --continue (resume downloads)   system wget
    grep/fgrep/egrep   forced --color=auto                    system grep variants
    dir / vdir         forced --color=auto                    system dir / vdir
    help config        intercepts "help config" → config-help  fish builtin help
    claude             auto-links AGENTS.md as CLAUDE.md before launch  command claude
    edit               multi-editor launcher (GUI/term + fallbacks)  $EDITOR/nvim/nano/vi

When C1 is disabled, `rm` uses bare `command rm` with no wrapper — files
are permanently deleted, not trashed. There is no intermediate safety net.

