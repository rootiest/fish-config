---
title: Viewing This Manual
manTitle: 11. VIEWING THIS MANUAL
sidebar:
  order: 15
helpKeywords:
- viewing
- manual
---

There are four ways to read this manual.

## The documentation website

    help config --html

Opens https://fish-config-docs.pages.dev/ in the default browser — the
Starlight-powered site built from `docs/manual/**` on every push to `main`.
It has a section sidebar and full-text search. Deep links to a specific
section aren't supported from the command line; once the site opens, use
its search box to jump straight to what you need.

## As a man page

    help config --man
    help config pkg --man

Opens the compiled docs/fish-config.1 directly via man -l, bypassing
the pager fallback chain. If a section keyword is given, the pager opens
at the nearest matching heading. The symlink is created once on first
run (like an install step) and MANPATH is set each session, enabling
the standard invocation:

    man fish-config

NOTE: fish-config (hyphen) is this config's man page. fish_config
(underscore) is fish's built-in browser-based configuration tool —
a completely separate command. Do not mix them up.

## In the terminal

    help config
    help config keybindings

Without a pager available beyond the basics, `help config [SECTION]` opens
the Markdown manual in the best available viewer, falling back through:

    1. ov + bat   section navigation + syntax highlighting (best)
    2. ov alone   section navigation, raw Markdown
    3. bat alone  syntax highlighting, use / to search
    4. man -l     pre-compiled man page (if available)
    5. less       plain text with line-jump
    6. cat        plain output

With ov, the Markdown renders with syntax highlighting and section-based
navigation:

    Space       next section
    ^           previous section
    Alt+u       toggle section list sidebar
    /           search forward
    n / N       next / previous search match
    g           go to line number
    j           interactive jump target (line, %, or 'section')
    q           quit

If SECTION is given, the pager opens at the first heading that matches the
keyword (case-insensitive; checks `docs/fish-config.index` aliases first,
then falls back to a normalized heading scan):

    help config keybindings
    help config abbreviations
    help config pkg
    help config logs
    help config fish-deps

## Reading the source directly

`docs/manual/**` is the single source of truth this manual, the man page,
and the website are all generated from. Numbered files and directories
correspond to the numbered sections in this manual — browse them in any
editor, or from a shell:

    cd ~/.config/fish/docs/manual
    grep -rn "keybindings" .
