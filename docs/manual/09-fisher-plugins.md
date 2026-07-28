---
title: Fisher Plugins
manTitle: 9. FISHER PLUGINS
sidebar:
  order: 13
helpKeywords:
- plugins
- fisher
---

Fisher is bootstrapped automatically on the **first interactive session** via
`conf.d/first_run.fish`. This also applies the Catppuccin Mocha theme and
prints a one-time welcome message (gated by `__fish_config_op_greeting`; set
it to 0 to suppress). Subsequent sessions skip all first-run logic with zero
overhead.

To re-trigger first-run initialization (e.g., after a fresh install or for
testing), run:

    set -Ue __fish_config_first_run_complete

Then open a new shell.

## Fisher-Managed Plugins

The following plugins are fully managed by Fisher. Their files are installed
into the repo directory by Fisher and are listed in `.gitignore` — do not
commit them. Fisher installs and updates them automatically.

    jorgebucaran/fisher           Plugin manager itself
    meaningful-ooo/sponge         Remove failed commands from history

## Sponge History Filtering

Sponge removes failed commands from history and, via conf.d/sponge_privacy.fish,
also filters privacy-sensitive commands through three layers:

Layer 1 — Static patterns (universal, persistent across sessions):
Commands matching any of these structural signatures are never recorded:

    --password / --token / --passphrase / --api-key flags with values
    Inline env assignments: GITHUB_TOKEN=xxx, MY_API_KEY=abc
    Fish set with sensitive names: set -gx GITHUB_TOKEN xxx
    URLs with embedded credentials: https://user:pass@host
    HTTP Authorization headers: curl -H "Authorization: ..."
    Basic auth flags: curl -u user:pass
    sshpass, docker login -p, openssl -passin/-passout

Layer 2 — Dynamic secret values (session globals, refreshed each login):
On the first prompt, after secrets.fish has loaded, the literal values of
all exported variables whose names suggest credentials (TOKEN, PASSWORD,
SECRET, API_KEY, etc.) are collected, regex-escaped, and added as a
session-scoped overlay.  Because globals shadow universals in Fish, the
combined list is what sponge sees.  Rotating a token takes effect on the
next login automatically.

Layer 3 — Per-command filter (sponge_filter_secrets):
Catches credentials in variables exported after login, such as tokens
sourced from a project .env file mid-session.

To add your own persistent patterns:

    set -U -a sponge_regex_patterns 'your-regex-here'

To mark additional variable NAMES as credential-bearing (so Layer 2 scrubs
their values), add name tokens — via `config-settings` → Sponge, or directly:

    set -U -a __fish_sponge_extra_sensitive ACME_API VAULT_PW

Tokens are folded into the Layer 2 name match case-insensitively as substrings,
so ACME_API also covers ACME_API_KEY. (The match uses `--entire` to return the
full variable name, so partial-name tokens dereference the right value.)

The `config-settings` Sponge page also surfaces sponge's own tuning variables —
sponge_delay, sponge_successful_exit_codes, sponge_purge_only_on_exit, and
sponge_allow_previously_successful — so they can be changed without typing
variable names.

## Bundled Plugin Functionality

The remaining plugin functionality is bundled directly with this config rather
than managed through Fisher. The bundled versions include customizations for
Fish 4.x compatibility and improved behavior that differ from their upstream
releases. Installing them through Fisher would overwrite these customizations.

Bundled components and their upstream origins:

    catppuccin/fish               → themes/ + conf.d/theme.fish
    PatrickF1/fzf.fish            → functions/_fzf_*.fish + conf.d/fzf.fish
    franciscolourenco/done        → conf.d/done.fish
    jorgebucaran/autopair.fish    → functions/_autopair_*.fish + conf.d/autopair.fish
    nickeb96/puffer-fish          → functions/_puffer_fish_*.fish + conf.d/puffer.fish

Do not run `fisher install` for these — it will overwrite the customized
versions. To update their behavior, edit the relevant bundled files directly.

## fish_plugins Manifest

The `fish_plugins` file at the config root:

    jorgebucaran/fisher           Plugin manager itself
    meaningful-ooo/sponge         Remove failed commands from history

To update all Fisher-managed plugins, run `fisher update` or `fish-deps
update` which calls it as its first step.

---
