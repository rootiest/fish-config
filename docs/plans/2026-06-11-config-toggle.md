# config-toggle Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build `config-toggle`, an interactive TUI that lets users cycle six opinionated-category variables and the master variable between ON / OFF / DEFAULT with immediate apply, across Universal and Session scopes.

**Architecture:** Three fish functions: the main `config-toggle` entry point handles argument parsing, terminal setup/teardown, and the event loop; `__config_toggle_draw` renders the 14-line panel in-place; `__config_toggle_get_val` reads a scope-specific variable value via `set --show` parsing. Changes apply immediately on each Space keypress via `set -U`/`set -g`/erase.

**Tech Stack:** Fish 4.x builtins only (`read`, `set`, `string`, `printf`, `tput`). No external dependencies.

**Spec:** `docs/specs/2026-06-11-config-toggle-design.md`

---

## File Map

| Action | Path | Purpose |
|--------|------|---------|
| Create | `functions/config-toggle.fish` | Entry point: arg parse, terminal setup/teardown, event loop |
| Create | `functions/__config_toggle_draw.fish` | Renders the 14-line TUI panel |
| Create | `functions/__config_toggle_get_val.fish` | Reads a variable's value in a specific scope |
| Modify | `docs/fish-config.md` | Add `config-toggle` entry after `config-update` (line ~1222) |
| Modify | `docs/fish-config.index` | Add `toggle` and `config-toggle` keywords |

---

## Panel Layout Reference

```
┌─ Opinionated Settings ────────────────────────────┐   ← line 1
│ ● Universal  ○ Session             Tab to switch  │   ← line 2
│──────────────────────────────────────────────────│   ← line 3
│  ▶ Aliases         [ ON      ]  cmd shadows       │   ← line 4
│    Auto-exec       [ ON      ]  startup           │   ← line 5
│    Overrides       [ DEFAULT ]  keys/env/prompt   │   ← line 6
│    Integrations    [ ON      ]  terminal coupling │   ← line 7
│    Logging         [ ON      ]  scrollback        │   ← line 8
│    Greeting        [ DEFAULT ]  fish_greeting     │   ← line 9
│    ──────────────────────────────────────────     │   ← line 10
│    Master          [ DEFAULT ]  disable all       │   ← line 11
│──────────────────────────────────────────────────│   ← line 12
│  ↑↓/jk: move  Space: cycle  Tab: scope  q: quit  │   ← line 13
└──────────────────────────────────────────────────┘   ← line 14
```

Outer width: 52 chars. Inner content: 50 chars. Panel = **14 lines**.

Content row layout (50 chars visible between `│`):
```
  [cursor 2]  [label padded to 12]  [  badge 7  ]   [desc padded to 17]   
= 2 + 2 + 12 + 3 + 7 + 4 + 17 + 3 = 50 chars
```

Badge values (7 chars, right-padded): `"ON     "` / `"OFF    "` / `"DEFAULT"`

---

## Variable Reference

| Row idx | Label | Variable |
|---------|-------|----------|
| 0 | Aliases | `__fish_config_op_aliases` |
| 1 | Auto-exec | `__fish_config_op_autoexec` |
| 2 | Overrides | `__fish_config_op_overrides` |
| 3 | Integrations | `__fish_config_op_integrations` |
| 4 | Logging | `__fish_config_op_logging` |
| 5 | Greeting | `__fish_config_op_greeting` |
| 6 | Master | `__fish_config_opinionated` |

State cycle on Space: `on → off → DEFAULT → on`

Apply commands:

| Result state | Universal scope | Session scope |
|---|---|---|
| on | `set -U <var> on` | `set -g <var> on` |
| off | `set -U <var> off` | `set -g <var> off` |
| DEFAULT | `set -Ue <var>` | `set -eg <var>` |

---

## Task 1: Scope-value reader helper

**Files:**
- Create: `functions/__config_toggle_get_val.fish`

- [ ] **Step 1: Create the file**

```fish
# Copyright (C) 2026 Rootiest
# SPDX-License-Identifier: AGPL-3.0-or-later

# SYNOPSIS
#   __config_toggle_get_val <varname> <scope>
#
# DESCRIPTION
#   Returns the current value of a named variable in the specified scope by
#   parsing `set --show` output. Outputs "on", "off", or "DEFAULT" (when
#   the variable is not set in that scope). Scope "session" maps to "global"
#   in fish's internal terminology.
#
# ARGUMENTS
#   varname  Variable name without $ prefix
#   scope    "universal" or "session"
#
# RETURNS
#   0  Always; prints "on", "off", or "DEFAULT" to stdout
#
# EXAMPLE
#   set result (__config_toggle_get_val __fish_config_op_aliases universal)
#   # result == "on" | "off" | "DEFAULT"
function __config_toggle_get_val
    set -l varname $argv[1]
    set -l scope $argv[2]

    # fish uses "global" in set --show output for what we call "session"
    set -l scope_kw $scope
    if test $scope = session
        set scope_kw global
    end

    set -l found 0
    for line in (set --show $varname 2>/dev/null)
        if string match -q "*$scope_kw scope*" $line
            set found 1
            continue
        end
        if test $found -eq 1
            set found 0
            # Format: $varname[1]: |value|
            set -l val (string replace -r '^\$[^\[]+\[1\]: \|(.+)\|$' '$1' $line 2>/dev/null)
            if test -n "$val" -a "$val" != $line
                echo $val
                return 0
            end
        end
    end

    echo DEFAULT
    return 0
end
```

- [ ] **Step 2: Verify it reads correctly**

In a fish shell, run:
```fish
set -U __fish_config_op_aliases on
set result (__config_toggle_get_val __fish_config_op_aliases universal)
echo "universal: $result"   # expected: on
set result (__config_toggle_get_val __fish_config_op_aliases session)
echo "session:   $result"   # expected: DEFAULT  (no global set)
set -g __fish_config_op_aliases off
set result (__config_toggle_get_val __fish_config_op_aliases session)
echo "session:   $result"   # expected: off
# cleanup
set -Ue __fish_config_op_aliases
set -eg __fish_config_op_aliases
```

- [ ] **Step 3: Commit**

```bash
git add functions/__config_toggle_get_val.fish
git commit -m "feat(config-toggle): add scope-specific variable reader helper"
```

---

## Task 2: Panel renderer

**Files:**
- Create: `functions/__config_toggle_draw.fish`

- [ ] **Step 1: Create the file**

```fish
# Copyright (C) 2026 Rootiest
# SPDX-License-Identifier: AGPL-3.0-or-later

# SYNOPSIS
#   __config_toggle_draw <cur_row> <cur_scope> <var1> ... <var7>
#
# DESCRIPTION
#   Renders the 14-line config-toggle TUI panel to stdout. Intended to be
#   called once on startup, then again after each keypress preceded by
#   `printf '\e[14A\e[J'` (cursor-up 14 lines + clear-to-end) to redraw
#   in place. Does not move the cursor — caller manages positioning.
#
# ARGUMENTS
#   cur_row    0–6, the currently highlighted row
#   cur_scope  "universal" or "session"
#   var1–var7  Variable names for rows 0–6 (in order per Variable Reference)
#
# RETURNS
#   0  Always
#
# EXAMPLE
#   __config_toggle_draw 0 universal \
#       __fish_config_op_aliases __fish_config_op_autoexec \
#       __fish_config_op_overrides __fish_config_op_integrations \
#       __fish_config_op_logging __fish_config_op_greeting \
#       __fish_config_opinionated
function __config_toggle_draw
    set -l cur_row   $argv[1]
    set -l cur_scope $argv[2]
    set -l vars      $argv[3..]

    set -l c_ok    (set_color green)
    set -l c_err   (set_color red)
    set -l c_dim   (set_color brblack)
    set -l c_sel   (set_color --bold magenta)
    set -l c_hi    (set_color --bold white)
    set -l c_head  (set_color --bold cyan)
    set -l c_reset (set_color normal)

    set -l labels  Aliases Auto-exec Overrides Integrations Logging Greeting Master
    set -l descs   "cmd shadows" startup "keys/env/prompt" "terminal coupling" scrollback fish_greeting "disable all"

    # Panel dimensions
    set -l IW 50   # inner width (chars between │ │)
    set -l HBR (string repeat -n $IW '─')

    # ── Scope tabs ────────────────────────────────────────
    if test $cur_scope = universal
        set -l u_label "$c_hi● Universal$c_reset"
        set -l s_label "○ Session  "
    else
        set -l u_label "○ Universal"
        set -l s_label "$c_hi● Session  $c_reset"
    end

    # ── Top border ────────────────────────────────────────
    # "─ Opinionated Settings " = 23 chars; fill rest to IW-1 then ┐
    printf '┌─%s Opinionated Settings %s┐\n' \
        $c_head $c_reset(string repeat -n (math $IW - 24) '─')

    # ── Scope tab line ────────────────────────────────────
    # Content: " ● Universal  ○ Session             Tab to switch "  (50 vis chars)
    printf '│ %s  %s%s│\n' \
        $u_label $s_label \
        (string repeat -n 12 ' ')"Tab to switch  "

    # ── Top divider ───────────────────────────────────────
    printf '│%s│\n' $HBR

    # ── Category rows 0–5 ─────────────────────────────────
    for i in (seq 0 5)
        set -l idx    (math $i + 1)
        set -l var    $vars[$idx]
        set -l label  $labels[$idx]
        set -l desc   $descs[$idx]

        set -l val (__config_toggle_get_val $var $cur_scope)

        # Badge: 7 visible chars, coloured
        switch $val
            case on
                set -l badge "$c_ok""ON     $c_reset"
            case off
                set -l badge "$c_err""OFF    $c_reset"
            case '*'
                set -l badge "$c_dim""DEFAULT$c_reset"
        end

        # Cursor: 2 visible chars
        if test $i -eq $cur_row
            set -l curs "$c_sel▶$c_reset "
        else
            set -l curs "  "
        end

        # Label padded to 12, desc padded to 17, right margin 3
        set -l lpad (string pad -r -w 12 -- $label)
        set -l dpad (string pad -r -w 17 -- $desc)

        printf '│  %s%s [ %s ]  %s   │\n' $curs $lpad $badge $dpad
    end

    # ── Separator before Master ───────────────────────────
    printf '│    %s  │\n' (string repeat -n (math $IW - 6) '─')

    # ── Master row (index 6) ──────────────────────────────
    set -l val (__config_toggle_get_val $vars[7] $cur_scope)
    switch $val
        case on
            set -l badge "$c_ok""ON     $c_reset"
        case off
            set -l badge "$c_err""OFF    $c_reset"
        case '*'
            set -l badge "$c_dim""DEFAULT$c_reset"
    end
    if test $cur_row -eq 6
        set -l curs "$c_sel▶$c_reset "
    else
        set -l curs "  "
    end
    printf '│  %s%s [ %s ]  %s   │\n' \
        $curs \
        (string pad -r -w 12 -- Master) \
        $badge \
        (string pad -r -w 17 -- "disable all")

    # ── Bottom divider ────────────────────────────────────
    printf '│%s│\n' $HBR

    # ── Keybind hint ──────────────────────────────────────
    printf '│  %s↑↓/jk: move  Space: cycle  Tab: scope  q: quit%s  │\n' \
        $c_dim $c_reset

    # ── Bottom border ─────────────────────────────────────
    printf '└%s┘\n' $HBR
end
```

- [ ] **Step 2: Smoke-test the renderer**

In a fish shell:
```fish
source functions/__config_toggle_draw.fish
source functions/__config_toggle_get_val.fish
__config_toggle_draw 0 universal \
    __fish_config_op_aliases __fish_config_op_autoexec \
    __fish_config_op_overrides __fish_config_op_integrations \
    __fish_config_op_logging __fish_config_op_greeting \
    __fish_config_opinionated
```

Expected: a 14-line bordered panel. Row 0 (Aliases) has `▶` in magenta. All badges show DEFAULT (dim) since no vars are set. Check that the panel is 52 chars wide.

- [ ] **Step 3: Verify with a value set**

```fish
set -U __fish_config_op_aliases on
__config_toggle_draw 0 universal \
    __fish_config_op_aliases __fish_config_op_autoexec \
    __fish_config_op_overrides __fish_config_op_integrations \
    __fish_config_op_logging __fish_config_op_greeting \
    __fish_config_opinionated
set -Ue __fish_config_op_aliases
```

Expected: Aliases row badge shows green `ON     `. All others show `DEFAULT`.

- [ ] **Step 4: Commit**

```bash
git add functions/__config_toggle_draw.fish
git commit -m "feat(config-toggle): add panel renderer helper"
```

---

## Task 3: Main function — skeleton, help flag, terminal setup

**Files:**
- Create: `functions/config-toggle.fish`

- [ ] **Step 1: Create the skeleton with help flag**

```fish
# Copyright (C) 2026 Rootiest
# SPDX-License-Identifier: AGPL-3.0-or-later

# SYNOPSIS
#   config-toggle [-h | --help]
#
# DESCRIPTION
#   Opens an interactive full-screen TUI for toggling the six opinionated
#   component categories (C1–C6) and the master disable variable without
#   having to remember variable names. Two scope tabs allow independent
#   per-scope configuration:
#
#     Universal — persists across all sessions (set -U / set -Ue)
#     Session   — active for the current shell only (set -g / set -eg)
#
#   Changes apply immediately on each Space keypress — no confirm step.
#   Always available regardless of __fish_config_opinionated state.
#
# ARGUMENTS
#   -h, --help  Print usage and exit
#
# RETURNS
#   0  Exited normally (q or Escape pressed)
#   1  Unknown flag passed
#
# EXAMPLE
#   config-toggle
function config-toggle --description 'Interactive TUI for toggling opinionated component settings'
    set -l c_head  (set_color --bold cyan)
    set -l c_cmd   (set_color --bold white)
    set -l c_flag  (set_color yellow)
    set -l c_dim   (set_color brblack)
    set -l c_err   (set_color red)
    set -l c_reset (set_color normal)

    # ── Argument parsing ──────────────────────────────────
    for arg in $argv
        switch $arg
            case -h --help
                echo "$c_head""Usage:$c_reset $c_cmd""config-toggle$c_reset $c_flag""[-h]$c_reset"
                echo
                echo "  Interactive TUI for toggling opinionated component categories."
                echo "  Changes apply immediately — no confirm step required."
                echo
                echo "$c_head""Navigation:$c_reset"
                echo "  $c_flag↑ ↓$c_reset or $c_flag""j k$c_reset    Move cursor up / down"
                echo "  $c_flag""Space$c_reset         Cycle: ON → OFF → DEFAULT → ON"
                echo "  $c_flag""Tab$c_reset           Switch scope (Universal ↔ Session)"
                echo "  $c_flag""q$c_reset / $c_flag""Escape$c_reset    Exit"
                echo
                echo "$c_head""Scopes:$c_reset"
                echo "  $c_flag""Universal$c_reset   Persistent across all sessions ($c_dim""set -U$c_reset)"
                echo "  $c_flag""Session$c_reset     Current session only ($c_dim""set -g$c_reset)"
                return 0
            case '*'
                echo "$c_err""Unknown option: $arg$c_reset" >&2
                echo "Run $c_cmd""config-toggle --help$c_reset for usage." >&2
                return 1
        end
    end
end
```

- [ ] **Step 2: Verify help output**

```fish
config-toggle --help
```

Expected: coloured usage output, exits 0.

```fish
config-toggle --bogus
echo $status   # expected: 1
```

- [ ] **Step 3: Commit**

```bash
git add functions/config-toggle.fish
git commit -m "feat(config-toggle): add function skeleton and help flag"
```

---

## Task 4: Event loop — navigation and scope switching

**Files:**
- Modify: `functions/config-toggle.fish` (add after the arg-parse block, before the final `end`)

- [ ] **Step 1: Add terminal setup, initial draw, and event loop**

Replace the final `end` of `config-toggle` with this block:

```fish
    # ── Variable list (matches Panel Layout Reference) ────
    set -l vars \
        __fish_config_op_aliases \
        __fish_config_op_autoexec \
        __fish_config_op_overrides \
        __fish_config_op_integrations \
        __fish_config_op_logging \
        __fish_config_op_greeting \
        __fish_config_opinionated

    set -l cur_row   0           # 0–6
    set -l cur_scope universal   # or "session"
    set -l panel_h   14          # total panel lines

    # ── Terminal setup ────────────────────────────────────
    printf '\e[?25l'             # hide cursor
    trap 'printf "\e[?25h"; printf "\n"' INT

    # ── Initial draw ──────────────────────────────────────
    __config_toggle_draw $cur_row $cur_scope $vars

    # ── Event loop ────────────────────────────────────────
    while true
        read -k 1 -l key

        switch $key
            case \e
                # Arrow key: ESC [ A/B — read 2 more chars with short timeout
                read -k 2 -l seq -t 0.1
                switch $seq
                    case '[A'   # Up arrow
                        set cur_row (math "max(0, $cur_row - 1)")
                    case '[B'   # Down arrow
                        set cur_row (math "min(6, $cur_row + 1)")
                end
                # If seq is empty (bare Escape), fall through to quit
                if test -z "$seq"
                    break
                end

            case k
                set cur_row (math "max(0, $cur_row - 1)")
            case j
                set cur_row (math "min(6, $cur_row + 1)")

            case \t   # Tab — switch scope
                if test $cur_scope = universal
                    set cur_scope session
                else
                    set cur_scope universal
                end

            case q Q
                break
        end

        # Redraw in place
        printf '\e[%dA\e[J' $panel_h
        __config_toggle_draw $cur_row $cur_scope $vars
    end

    # ── Cleanup ───────────────────────────────────────────
    printf '\e[?25h'   # restore cursor
end
```

- [ ] **Step 2: Verify navigation**

```fish
config-toggle
```

Expected:
- Panel appears, cursor is hidden
- ↑/↓ and j/k move the `▶` cursor between rows
- Tab switches the scope tab highlight between `● Universal` and `● Session`
- `q` or Escape exits cleanly and restores the cursor

- [ ] **Step 3: Commit**

```bash
git add functions/config-toggle.fish
git commit -m "feat(config-toggle): add event loop with navigation and scope switching"
```

---

## Task 5: Cycling + immediate apply

**Files:**
- Modify: `functions/config-toggle.fish` (add Space handler inside the event loop)

- [ ] **Step 1: Add the Space case to the switch block**

Inside the `switch $key` block, add a `case ' '` handler. Insert it after the `case \t` block:

```fish
            case ' '
                set -l varname $vars[(math $cur_row + 1)]
                set -l cur_val (__config_toggle_get_val $varname $cur_scope)

                # Cycle: on → off → DEFAULT → on
                switch $cur_val
                    case on
                        set -l next_val off
                    case off
                        set -l next_val DEFAULT
                    case '*'   # DEFAULT or any unrecognised
                        set -l next_val on
                end

                # Apply immediately
                switch $cur_scope
                    case universal
                        switch $next_val
                            case on
                                set -U $varname on
                            case off
                                set -U $varname off
                            case DEFAULT
                                set -Ue $varname
                        end
                    case session
                        switch $next_val
                            case on
                                set -g $varname on
                            case off
                                set -g $varname off
                            case DEFAULT
                                set -eg $varname
                        end
                end
```

- [ ] **Step 2: Verify cycling and immediate apply**

```fish
config-toggle
```

Expected:
- Navigate to **Aliases** (row 0), press Space → badge changes to green `ON     `, variable set immediately
- Press Space again → badge changes to red `OFF    `
- Press Space again → badge changes to dim `DEFAULT`
- Press Space again → back to green `ON     `

Verify the variable was actually set:
```fish
# In another terminal or after quitting:
echo $__fish_config_op_aliases   # should reflect last state set
```

- [ ] **Step 3: Verify cross-scope independence**

```fish
config-toggle
# Navigate to Integrations, Tab to Session, Space to ON
# Tab back to Universal — badge should still show DEFAULT (separate scope)
```

Expected: Universal and Session values for the same row are independent.

- [ ] **Step 4: Commit**

```bash
git add functions/config-toggle.fish
git commit -m "feat(config-toggle): add Space cycling with immediate apply"
```

---

## Task 6: Docs update

**Files:**
- Modify: `docs/fish-config.md`
- Modify: `docs/fish-config.index`

- [ ] **Step 1: Add entry to fish-config.md**

In `docs/fish-config.md`, find the `### config-update` section (line ~1203). Insert the following block **immediately after** the `config-update` section ends (after the last example line `config-update --force`, before `### bash`):

```markdown
### config-toggle

    Synopsis:  config-toggle [-h]

    Opens an interactive full-screen TUI for toggling the six opinionated
    component categories (C1–C6) and the master disable variable without
    having to type or remember variable names. Two scope tabs allow
    independent per-scope configuration:

      Universal — persists across all sessions (set -U)
      Session   — current shell only (set -g)

    Changes apply immediately on each Space keypress. Always available
    regardless of the __fish_config_opinionated master state.

    Navigation:
      ↑ ↓ / j k   Move cursor
      Space        Cycle: ON → OFF → DEFAULT → ON
      Tab          Switch scope (Universal ↔ Session)
      q / Escape   Exit

    Flags:
      --help / -h   Show usage.

    config-toggle

```

- [ ] **Step 2: Add entries to fish-config.index**

In `docs/fish-config.index`, find the section that contains `config-help` and `config-update` keyword entries. Add after the last `config-update` line:

```
config-toggle=### config-toggle
toggle=### config-toggle
```

- [ ] **Step 3: Verify docs are reachable**

```fish
config-help toggle
```

Expected: docs pager opens at the `config-toggle` section.

- [ ] **Step 4: Commit**

```bash
git add docs/fish-config.md docs/fish-config.index
git commit -m "docs(config-toggle): add config-toggle entry to offline docs and index"
```

---

## Self-Review

**Spec coverage check:**

| Spec requirement | Covered by |
|---|---|
| Interactive TUI, colorful | Task 2 (renderer with set_color) |
| ON / OFF / DEFAULT states | Tasks 2 + 5 (badge display + cycle logic) |
| Universal / Session scope tabs | Tasks 3 + 4 (tab line + Tab key handler) |
| Immediate apply on toggle | Task 5 (set -U/g/erase in Space handler) |
| Tab key switches scope | Task 4 |
| Always available (no guard) | Task 3 (function has no op_enabled wrapper) |
| -h/--help per Convention §12 | Task 3 |
| License header + docblock | Tasks 1, 2, 3 |
| Color palette (Convention §11) | Tasks 2, 3 |
| Docs update (Convention §10) | Task 6 |
| docs/fish-config.index update | Task 6 |

**Placeholder scan:** No TBDs, TODOs, or "handle edge cases" vagueness found. All code blocks are complete.

**Type consistency:** `__config_toggle_get_val` returns "on", "off", or "DEFAULT" — the Space handler's `switch $cur_val` matches against those exact strings. The `$vars` array indices are 1-based in fish (used as `$vars[(math $cur_row + 1)]`) consistently throughout.
