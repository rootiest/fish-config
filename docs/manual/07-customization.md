---
title: Customization
manTitle: 7. CUSTOMIZATION
sidebar:
  order: 11
helpKeywords:
- customization
- customize
---
This section explains how to adapt the configuration to your specific workflow, including local machine overrides and opinionated component toggles.


## Machine-local Configuration

Place machine-specific settings that should not be committed to git in:

    $__fish_user_dots_path/local.fish

`__fish_user_dots_path` defaults to `~/.config/.user-dots/fish`. Set a
custom location with:

    set -U __fish_user_dots_path /path/to/your/dots/fish

Typical uses: additional PATH entries, local aliases, hostname-specific env
vars, work-specific tool configs.

For convenience, a git-ignored `user-dots` symlink in the fish config
directory tracks `$__fish_user_dots_path` so the overlay can be browsed from
`~/.config/fish/`. It is created if missing and repointed if the path changes.
Opt out by setting `__fish_user_dots_symlink` to a falsy value, or toggling
"Dots link" off on the config-settings Paths page — this stops generation and
removes any existing link. It only ever manages a symlink and never clobbers a
real file or directory at that path.


## Secrets and API Keys

    $__fish_user_dots_path/secrets.fish

Store API tokens, GPG keys, private credentials here. This file is never
committed. It is sourced by local.fish directly, not by config.fish.

`local.fish` is sourced at the end of config.fish on every interactive
session, so it and its companion secrets.fish can override anything set
earlier.


## Overriding Configuration Variables

Any variable set in local.fish after the main config loads takes effect.
Example: to increase the scrollback history limit:

    # in local.fish
    set -gx SCROLLBACK_HISTORY_MAX_FILES 200


## Fish Universal Variables

Some settings (fzf colors, theme) are stored in fish_variables via
`set -U`. These are machine-local and git-ignored. Do not commit
fish_variables.


## Opinionated Components (Minimal Mode)

Every opinionated piece of this config is active by default but can be
switched off through six category opt-out variables, each evaluated via
`__fish_variable_check`. Set a variable to any falsy value (0, false, no,
off, n) to disable its category; erase it or set a truthy value (1, true,
yes, on, y) to re-enable. Unset means enabled — except for C5 logging, which
is opt-in (see below).

An explicit per-category truthy value takes precedence over the master
switch: setting `__fish_config_opinionated`=0 disables all unset categories,
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


## Prompt and Theme

### Starship

The primary prompt is Starship, initialized by conf.d/starship.fish.
Configure it via ~/.config/starship.toml.

conf.d/starship.fish defines a fish_prompt wrapper that only activates when
starship is in PATH. It emits OSC 133;A (prompt start) immediately before
Starship renders and OSC 133;B (input start) immediately after, placing both
markers on the prompt line itself. This allows ov to use them as sticky
section headers when browsing scrollback logs. Without Starship, fish's
built-in prompt handles these markers automatically.

### Catppuccin Fallback Prompt

When Starship is absent or C3 overrides are disabled, a built-in nim-style
two-line prompt activates from functions/fish_prompt.fish. No external
dependencies — fish builtins only.

Layout:

    ┬─[user@host:~/path] (main)
    ╰─>$

Elements:

    user        Yellow (Catppuccin Yellow); red if root
    @host       Blue (local) or Teal (SSH)
    ~/path      prompt_pwd abbreviation (Catppuccin Text)
    (main)      Current git branch in Catppuccin Pink; omitted outside repos
    ─[V:name]   Active Python venv basename; omitted when none
    ─[N/I/R/V]  Vi-mode indicator when vi bindings are active
    ┬─ / ╰─>    Connector lines: Catppuccin Green on success, Red on failure

The right prompt (fish_right_prompt.fish) always renders, regardless of C3
state. On failure it shows a red ✘ and the exit code; on success it shows
only the dim timestamp. When starship is installed and C3 is enabled, the
active Docker context is also shown (if non-default):

    ✘ 1   󰡨 myctx   Fri Jun 12 00:51:21 2026     ← failed, starship+C3 active
    ✘ 1   Fri Jun 12 00:51:21 2026               ← failed, fallback prompt
    Fri Jun 12 00:51:21 2026                     ← success (no ✘)

### FZF

FZF is themed to Catppuccin Mocha via FZF_DEFAULT_OPTS set in
integrations/fzf.fish. The colors applied:

    Background:   #1E1E2E (base)    #313244 (surface0)
    Foreground:   #CDD6F4 (text)
    Highlights:   #F38BA8 (red)     #CBA6F7 (mauve)    #B4BEFE (lavender)

To customize, override FZF_DEFAULT_OPTS in local.fish.

### Catppuccin Mocha Syntax Highlighting

The Catppuccin Mocha theme ships with this config in themes/ and is applied
on first run via `conf.d/first_run.fish`. Colors are stored in fish_variables
(universal). To switch variants, install a different theme from themes/:

    fish_config theme save "Catppuccin Latte"

`---`
