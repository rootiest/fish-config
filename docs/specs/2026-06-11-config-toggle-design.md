# Design: `config-toggle`

**Date:** 2026-06-11  
**Status:** Approved

---

## Overview

A new interactive TUI function, `config-toggle`, that lets users toggle the six opinionated-component category variables and the master variable without having to type or remember variable names. It is modelled on the Claude Code settings panel UX: tabbed scope selector, arrow-key row navigation, Space to cycle state, instant apply on each keypress.

The function lives at `functions/config-toggle.fish` and follows all project conventions (license header, man-page docblock, color palette, help flag). It is **always available** regardless of the opinionated-component state — it must never be wrapped in a guard.

---

## Variables Under Management

| Label | Variable | Category |
|---|---|---|
| Aliases | `__fish_config_op_aliases` | C1 |
| Auto-exec | `__fish_config_op_autoexec` | C2 |
| Overrides | `__fish_config_op_overrides` | C3 |
| Integrations | `__fish_config_op_integrations` | C4 |
| Logging | `__fish_config_op_logging` | C5 |
| Greeting | `__fish_config_op_greeting` | C6 |
| Master | `__fish_config_opinionated` | master |

---

## UI Layout

A fixed-height bordered panel rendered with ANSI escape sequences (`tput` for terminal dimensions, `\e[` sequences for cursor positioning). The panel redraws in-place on every keystroke — no scrolling, no paging.

```
┌─ Opinionated Settings ───────────────────────┐
│ ● Universal  ○ Session          Tab to switch │
│──────────────────────────────────────────────│
│  ▶ Aliases         [ ON      ]  cmd shadows   │
│    Auto-exec       [ ON      ]  startup       │
│    Overrides       [ DEFAULT ]  keys/env/prompt│
│    Integrations    [ ON      ]  terminal coupling│
│    Logging         [ ON      ]  scrollback    │
│    Greeting        [ DEFAULT ]  fish_greeting │
│    ────────────────────────────────────────── │
│    Master          [ DEFAULT ]  disable all   │
│──────────────────────────────────────────────│
│  ↑↓ move  Space cycle  Tab scope  q quit      │
└──────────────────────────────────────────────┘
```

### State badge colors

| State | Display | Color |
|---|---|---|
| `ON` | `[ ON      ]` | green (`set_color green`) |
| `OFF` | `[ OFF     ]` | red (`set_color red`) |
| `DEFAULT` | `[ DEFAULT ]` | dim (`set_color brblack`) |

---

## Keybindings

| Key | Action |
|---|---|
| `↑` / `k` | Move cursor up one row |
| `↓` / `j` | Move cursor down one row |
| `Space` | Cycle selected row: ON → OFF → DEFAULT → ON |
| `Tab` | Switch active scope tab (Universal ↔ Session) |
| `q` / `Escape` | Exit, leaving all values in place |

---

## Scope Tabs

Two tabs: **Universal** and **Session**. Only one is active at a time (Tab to switch). The active tab label is highlighted.

- **Universal tab** reads/writes universal variables (`set -U` / `set -Ue`)
- **Session tab** reads/writes global variables for the current shell session (`set -g` / `set -eg`)

Both scopes can be set independently. For example: `Integrations = off` universally and `Integrations = on` for the current session.

---

## State Management & Immediate Apply

Each Space keypress on a row runs the corresponding fish command **immediately** — no confirm step, no exit required.

| Resulting state | Universal scope | Session scope |
|---|---|---|
| `ON` | `set -U <var> on` | `set -g <var> on` |
| `OFF` | `set -U <var> off` | `set -g <var> off` |
| `DEFAULT` | `set -Ue <var>` (erase) | `set -eg <var>` (erase) |

The TUI re-reads the live variable value before drawing each row, so external changes are reflected on next redraw.

---

## Function Signature

```fish
config-toggle [-h | --help]
```

No subcommands or positional arguments. `-h`/`--help` prints usage per Convention §12 and exits.

---

## Implementation Notes

- Use `tput lines` and `tput cols` to detect terminal size; center or top-align the panel accordingly.
- Save the cursor position on entry (`\e[s` or `tput sc`), hide the cursor (`tput civis`), and restore both on exit (including on `q`, Escape, and interrupt signals via `trap`).
- Use `read -k 1` to capture single keystrokes without Enter. Handle escape sequences for arrow keys (`\e[A` = up, `\e[B` = down) by reading the next 2 bytes after `\e`.
- The Master row is separated from the category rows by a divider line.
- The panel width is fixed at 48 characters (fits an 80-column terminal comfortably).
- Inline short descriptions (e.g. "cmd shadows", "startup", "keys/env/prompt") are shown to the right of each state badge.
- `trap` on `SIGINT` and function exit to restore terminal state (show cursor, restore position) so an abrupt Ctrl-C doesn't leave the terminal broken.

---

## Conventions Checklist

- [ ] License header (Convention §1)
- [ ] Man-page docblock: SYNOPSIS, DESCRIPTION, ARGUMENTS, RETURNS, EXAMPLE (Convention §4)
- [ ] Color palette variables at top of output block (Convention §11)
- [ ] `-h`/`--help` flag (Convention §12)
- [ ] No guard wrapper (function must be always available)
- [ ] Update `docs/fish-config.md` with new function entry (Convention §10)
- [ ] Update `docs/fish-config.index` to include `config-toggle`
