---
title: C1 — Command Shadows
---

Disabling `__fish_config_op_aliases` restores standard system behavior for
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
    cp / mv            forced -i confirmation prompt          cp / mv unmodified
    wget               forced --continue (resume downloads)   system wget
    grep/fgrep/egrep   forced --color=auto                    system grep variants
    dir / vdir         forced --color=auto                    system dir / vdir
    help config        intercepts "help config" → config-help  fish builtin help
    claude             ensures AGENTS/ is scaffolded before launch      command claude
    edit               multi-editor launcher (GUI/term + fallbacks)  $EDITOR/nvim/nano/vi

When C1 is disabled, `rm` uses bare `command rm` with no wrapper — files
are permanently deleted, not trashed. There is no intermediate safety net.

`history` itself is never shadowed — every function in this config that
reads history depends on its stock builtin semantics. `pretty-history`
(same `aliases-tricks` toggle) is a separate command that prints history
with a timestamp prepended to every entry.

## Sub-categories

`__fish_config_op_aliases` sub-divides into six sub-categories, each with
its own `__fish_config_op_aliases_<slug>` toggle:

## filesystem

`ls`, `cat`, `cd`, `du`, `mkdir`, `rm`, `mv`, and `cd`/zoxide navigation --
the everyday filesystem-inspection and -modification shadows.

## search

`rg`, with its Kitty hyperlink formatting.

## network

`ping`, `ssh`, and `yt-dlp` -- shadows that talk to the network.

## monitor

`top` -> `btop`.

## shell-tools

`bash` (XDG bashrc + `$SHELL` reset), `less` (`$PAGER` fallback chain),
and the `help config` interception.

## dev-tools

`claude` (AGENTS/ scaffolding) and `edit` (multi-editor
launcher), plus `agy`.

## For function authors

Calling one of these names bare from inside your own function means the
override runs whenever C1 (or its sub-category) is on — which may not be
what your function wants: a shadow can change stdout (`cat`'s syntax
highlighting, `mkdir`'s tree display), prompt interactively where none is
expected (`cp`/`mv`'s forced `-i`), or reshape output structurally (`ls`'s
icons/columns, `rg`'s hyperlink markers). If your function's logic depends
on stock behavior, bypass the shadow deterministically, regardless of the
toggle state:

    Shadow                  Bypass                        Why
    ─────────────────────────────────────────────────────────────────────────
    ls, cat, rm, less, du,  command <name>                Real external
    top, ping, ssh, rg,                                    binaries — a
    mkdir, bash, cp, mv,                                    real system command
    wget, grep/fgrep/egrep,                                exists to fall
    dir/vdir, claude                                        back to.
    cd                       builtin cd                    The one true
                                                             fish builtin
                                                             in this table.
    help config              __original_help $argv         `help` is neither
                                                             a builtin nor an
                                                             external binary
                                                             (embedded in the
                                                             fish binary
                                                             itself) — see
                                                             conf.d/help.fish
                                                             for why the
                                                             wrapper keeps its
                                                             own backup copy.
    edit                     (nothing to bypass to)         Purely our own
                                                             invention, no
                                                             stock command
                                                             exists. Call
                                                             $EDITOR/$VISUAL
                                                             yourself if you
                                                             want a plain
                                                             editor launch.

A function's own doc header records which of these it depends on: see the
`CLASSIFICATION` label (`uses-shadow(...)` / `bypasses-shadow(...)`),
documented in full at
[`docs/function-classification-schema.md`](https://git.rootiest.dev/rootiest/fish-config/src/branch/main/docs/function-classification-schema.md).

