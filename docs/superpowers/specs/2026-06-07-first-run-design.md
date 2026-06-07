# First-Run Initialization Routine — Design Spec

**Date:** 2026-06-07
**Status:** Approved

---

## Goal

Provide a mechanism for code/actions that should run exactly once — on the first interactive fish session after the config is installed or reset. Subsequent sessions skip all first-run logic entirely with zero overhead.

---

## Architecture

### State detection

A fish **universal variable** (`__fish_config_first_run_complete`) acts as the persistent flag. Universal variables survive shell exits and are stored in `~/.config/fish/fish_variables`. The flag is set to `1` immediately before any first-run actions execute, so a crash mid-run does not re-trigger next session.

### File: `conf.d/first_run.fish`

A single auto-sourced file in `conf.d/`. Fish loads all `conf.d/` files before `config.fish`, so this file cannot rely on PATH additions made in `config.fish`. That is acceptable: all first-run actions only need system-level binaries (`curl`, `fish`) that are in PATH unconditionally.

### Guard pattern

```fish
if status is-interactive
    if not set -q __fish_config_first_run_complete
        set -U __fish_config_first_run_complete 1
        # first-run actions here
    end
end
```

The `status is-interactive` guard prevents the routine from firing in scripts, completions, or subshells.

---

## First-Run Actions (in order)

1. **Welcome message** — print a brief one-time greeting identifying the config and key commands.
2. **Fisher bootstrap** — automatically install Fisher and all plugins from `fish_plugins` (replaces the interactive Y/n prompt currently in `config.fish`).
3. **Theme** — apply `Catppuccin Mocha` via `fish_config theme choose`.

---

## Changes to `config.fish`

The existing interactive Fisher bootstrap block (lines ~118–130) is removed. `first_run.fish` owns that responsibility. The `config.fish` block was guarded by `not type -q fisher`; the new file guards by the universal variable instead, which is cleaner and avoids re-prompting if Fisher is uninstalled manually.

---

## Reset mechanism

To re-trigger first-run (e.g., for testing):

```fish
set -Ue __fish_config_first_run_complete
```

A commented-out version of this command is included at the top of `first_run.fish`.

---

## Error handling

- Fisher install failure is surfaced to the user via stderr but does not abort the session.
- Theme application is guarded: only runs if `fish_config` is available.
- All first-run actions are wrapped in `if status is-interactive` to prevent execution in non-interactive contexts.

---

## Files changed

| File | Change |
|------|--------|
| `conf.d/first_run.fish` | **New** — first-run guard and actions |
| `config.fish` | Remove interactive Fisher bootstrap block (~lines 118–130) |

---

## Success criteria

- First launch: welcome message printed, Fisher + plugins installed, theme set.
- Second launch: nothing extra runs.
- `set -Ue __fish_config_first_run_complete` followed by new shell re-triggers all actions.
- Non-interactive shells (`fish -c "echo hi"`) are unaffected.
