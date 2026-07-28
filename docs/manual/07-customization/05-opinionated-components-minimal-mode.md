---
title: Opinionated Components (Minimal Mode)
---

Every opinionated piece of this config is active by default but can be
switched off through six category opt-out variables, each evaluated via
__fish_variable_check. Set a variable to any falsy value (0, false, no,
off, n) to disable its category; erase it or set a truthy value (1, true,
yes, on, y) to re-enable. Unset means enabled — except for C5 logging, which
is opt-in (see below).

An explicit per-category truthy value takes precedence over the master
switch: setting __fish_config_opinionated=0 disables all unset categories,
but a category with an explicit truthy value remains enabled regardless.

C5 (logging) is the one exception to "unset means enabled". Because it
writes terminal output to disk, it is opt-in: unset means disabled, and the
master switch cannot enable it. Only an explicit truthy value turns logging
on.

    Variable                        Disables
    ────────────────────────────────────────
    __fish_config_op_aliases        Command shadows and flag injection:
                                    ls->eza, cat->bat, cd->zoxide,
                                    rm->trash, less->ov, top->btop,
                                    ping->prettyping, ssh->kitten,
                                    du->duf/dust, mkdir/bash wrappers,
                                    history timestamps, grep/cp/mv/wget
                                    flag injection, help intercept, claude
                                    AGENTS.md auto-link
    __fish_config_op_autoexec       Startup side-effects: Fisher
                                    bootstrap, theme apply, paru/yay
                                    wrapper generation, auto venv
                                    activation, WakaTime hook
    __fish_config_op_overrides      Key and env overrides: Vi mode,
                                    exit->smart_exit, PAGER/MANPAGER,
                                    CDPATH, bang-bang system, autopair,
                                    puffer, starship prompt, theme
                                    colors, FZF_DEFAULT_OPTS, right
                                    prompt
    __fish_config_op_integrations   Terminal/tool coupling: Kitty/
                                    WezTerm window abbreviations, done
                                    notifications, spwin/tab/split,
                                    hist, logs, upgrade, WakaTime
    __fish_config_op_logging        Logging & capture (OPT-IN — this one
                                    is off unless explicitly enabled):
                                    scrollback capture on exit, paru/yay
                                    AUR log wrappers, Kitty watcher
                                    capture; sentinel file coordinates
                                    cross-process state
    __fish_config_op_greeting       Greeting & first-run UI: per-session
                                    fish_greeting override (defines empty
                                    function late in config.fish to
                                    suppress distro greetings such as
                                    CachyOS fastfetch); first-run welcome
                                    banner in conf.d/first_run.fish

Examples:

    # Disable command shadows only (rm becomes plain rm again):
    set -U __fish_config_op_aliases off

    # Turn session logging on (opt-in; off until you do this):
    set -U __fish_config_op_logging on

    # Full minimal mode — disable all six categories at once:
    set -U __fish_config_opinionated 0

    # Re-enable everything (except C5 logging, which stays opt-in):
    set -Ue __fish_config_opinionated

    # Minimal mode but keep the greeting:
    set -U __fish_config_opinionated 0
    set -U __fish_config_op_greeting 1
    # (erase both to go back to full-flavor defaults)

For an interactive alternative to setting these variables by hand, run
config-settings — a full-screen TUI that flips any category (including C5
logging) on or off, per session or universally. See its entry in Section 5.

NOTE:
  - Command shadows (rm, cat, ls, ...) react immediately; conf.d-level components (bindings, prompt, abbreviations, hooks) take effect in new shells.
  - With aliases disabled, rm falls back to bare `command rm` — files are deleted permanently, not trashed.
  - Disabled integration commands (spwin, tab, split, hist, logs, upgrade) print an error naming the variable that disabled them.
  - On CachyOS, the distro fish config's own aliases, history override, and bang-bang bindings are stripped per category as well.

