---
title: Components Reference
manTitle: 8. COMPONENTS REFERENCE
sidebar:
  order: 12
helpKeywords:
- componentsreference
---
The following tables detail every component in each category. Use this
reference to understand exactly which behaviors change when you toggle a
category variable.

    Category   Description
    ──────────────────────────────────────────────────────────────────────────
    C1         [Command Shadows](/08-components-reference/01-c1-command-shadows/) — Wraps destructive commands (rm, cp) to be safe by default
    C2         [Startup Side-Effects](/08-components-reference/02-c2-startup-side-effects/) — Bootstraps Fisher, generates wrappers, auto-activates venvs
    C3         [Overrides](/08-components-reference/03-c3-key-and-environment-overrides/) — Overrides cd, sets Vi mode, binds <CR> to smart_enter
    C4         [Integrations](/08-components-reference/04-c4-terminal-and-tool-integration/) — Kitty/Wezterm integrations, starship hooks, fzf theme
    C5         [Logging and Capture](/08-components-reference/05-c5-logging-and-capture/) — Session logs, command duration
    C6         [Greeting & First-Run UI](/08-components-reference/06-c6-greeting-and-first-run-ui/) — Custom startup banner

Each category further sub-divides into two to six sub-categories (25 in
total) with their own `__fish_config_op_<category>_<subcategory>` toggles
-- see that category's page for its sub-category list.

## Per-function overrides: `C0`/`always`

Every guarded function or file can also carry a reserved `always/on` or
`always/off` tag in its `# COMPONENT` header, independent of every C1-C6
category and sub-category toggle and invisible to `config-settings`. An
`always/off` tag disables that function unconditionally; an `always/on`
tag enables it unconditionally, ignoring the state of every other tagged
sub-category. This is a per-function escape hatch for cases too granular
or too idiosyncratic to justify a taxonomy entry -- edit the header
directly and run `__fish_config_op_registry_rebuild` to apply the change.
