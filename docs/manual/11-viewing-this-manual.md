---
title: Viewing This Manual
manTitle: 11. VIEWING THIS MANUAL
sidebar:
  order: 15
helpKeywords:
- viewing
- manual
---

## With ov (recommended)

    help config

ov renders the Markdown with syntax highlighting and section-based
navigation.

    Space       next section
    ^           previous section
    Alt+u       toggle section list sidebar
    /           search forward
    n / N       next / previous search match
    g           go to line number
    j           interactive jump target (line, %, or 'section')
    q           quit

## With bat

    bat --language=markdown --paging=always ~/.config/fish/docs/fish-config.md

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

## In the browser (HTML)

    help config --html
    help config pkg --html

Opens docs/html/index.html in the default web browser. If a section
keyword is given, the browser opens directly at the matching anchor
(resolved via docs/html/sitemap.json). Browser detection queries the
system's x-scheme-handler/https MIME entry (via xdg-mime) to find the
real browser binary, then falls back through known browser binaries
(firefox, chromium, vivaldi, etc.), and finally xdg-open as a last
resort. Set $fish_help_browser or $BROWSER to override.

## As a wiki

The generated Markdown wiki lives in docs/wiki/. index.md provides the
project overview and a full table of contents. Each section page has a
navigation bar at the top linking to every other section.

The wiki is auto-generated from this file by the CI pipeline on every
push to main that changes docs/fish-config.md.

## Jumping to a section

    help config keybindings
    help config abbreviations
    help config pkg
    help config logs
    help config fish-deps

The keyword is matched case-insensitively against section headings.
