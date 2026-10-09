---
title: C2 — Startup Side-Effects
---

These run automatically without any user action. Disabling
`__fish_config_op_autoexec` prevents all of them.

    Component                  Trigger              What it does
    ───────────────────────────────────────────────────────────────────────────
    Fisher bootstrap           First shell only     Downloads and installs fisher
    Fisher update              After bootstrap      Installs all fish_plugins entries
    Catppuccin Mocha theme     First shell only     Applies theme via fish_config
    paru wrapper               Every startup        Writes ~/.local/bin/paru wrapper
    yay wrapper                Every startup        Writes ~/.local/bin/yay wrapper
    Python venv activation     On every cd          Sources .venv/bin/activate.fish
    WakaTime command hook      On every command     Reports to WakaTime API
    Auto-pull fast-forward     On entering a repo   Background ff-only git pull
    user-dots symlink          Every startup        Links $__fish_config_dir/user-dots
                                                    to $__fish_user_dots_path

When C2 is disabled: no Fisher install, no theme application, no paru/yay
wrapper generation, no automatic venv activation, no WakaTime reporting,
no auto-pull (the PWD handler is never registered), and the user-dots
convenience symlink is not created. The symlink is git-ignored and only ever
managed as a symlink — a real file or directory at that path is left untouched.
The symlink has its own opt-out independent of C2: set `__fish_user_dots_symlink`
to a falsy value (or toggle "Dots link" off on the config-settings Paths page)
to stop generating it and remove any existing link — honoured even when C2 is
enabled. Managed by the `__fish_user_dots_link` helper.
The first-run completion marker (`__fish_config_first_run_complete`) is still
set so the init does not re-run on subsequent shells. A failed Fisher bootstrap
is tracked separately (`__fish_config_bootstrap_pending`) and retried at most
once a day while C2 and the `plugin-management` sub-category are enabled.

Python venv activation fires on every directory change. If a directory uses
direnv (`.envrc` present), direnv takes priority and auto-venv is skipped for
that directory.

Auto-pull fast-forwards opted-in repositories in the background when you cd
into them. The fish-config repo is always covered; other repos are added with
the `auto-pull` command (see its entry in the functions reference). It only
ever fast-forwards a clean repo whose branch has an upstream — never rebases,
merges, or overwrites work — so it is a no-op on dirty trees, divergent
branches, or repos without a remote. Its fetch never prompts for
credentials, passphrases or host keys; a remote that needs them, or cannot
be reached, is skipped quietly (within 10s for ssh, 60s overall where
`timeout` is installed). The handler fires once per repo entry
(not on every sub-directory `cd`). The registry is machine-local at
`$__fish_user_dots_path/auto-pull.list` (defaults to `~/.config/.user-dots/fish/auto-pull.list`) and is never committed.

## Sub-categories

`__fish_config_op_autoexec` sub-divides into five sub-categories, each
with its own `__fish_config_op_autoexec_<slug>` toggle:

## plugin-management

Fisher bootstrap on first run.

## pkg-wrappers

`paru`/`yay` wrapper generation.

## venv

Automatic Python virtualenv activation.

## telemetry

The WakaTime hook's startup bootstrap.

## sync

Auto-pull background fast-forward, and the user-dots convenience symlink.

