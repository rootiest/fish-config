# 11. VIEWING THIS MANUAL

**Sections:** [Index](index.md) | [1. Configuration Variables](1-configuration-variables.md) | [2. Path Setup](2-path-setup.md) | [3. Key Bindings](3-key-bindings.md) | [4. Abbreviations](4-abbreviations.md) | [5. Functions Reference](5-functions-reference.md) | [6. Dependency Catalog](6-dependency-catalog.md) | [7. Customization](7-customization.md) | [8. Fisher Plugins](8-fisher-plugins.md) | [9. Installation](9-installation.md) | [10. Personalization](10-personalization.md) | **11. Viewing This Manual**

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
