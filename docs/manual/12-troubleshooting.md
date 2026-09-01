---
title: Troubleshooting
manTitle: 12. TROUBLESHOOTING
sidebar:
  order: 16
helpKeywords:
- troubleshooting
- troubleshoot
- faq
- help
- uninstall
- revert
---

This section covers common issues, their solutions, and how to safely revert changes or uninstall the configuration entirely.

## Uninstalling and Reverting to Backup

The installation step backs up any existing config to `~/.config/fish.bak`.
To revert:

    rm -rf ~/.config/fish
    mv ~/.config/fish.bak ~/.config/fish

If no backup exists, remove the directory and let Fish regenerate a default
config on next launch:

    rm -rf ~/.config/fish
    fish -c 'fish_config theme choose "Fish default"'

Clean up files generated outside the config directory:

    rm -f ~/.local/bin/paru ~/.local/bin/yay        # AUR log wrappers
    rm -f ~/.local/share/man/man1/fish-config.1     # man page symlink
    rm -f ~/.config/fish/.logging_disabled           # C5 sentinel

Erase universal variables set by this config:

    for v in (set -Un | string match '__fish_config*')
        set -Ue $v
    end
    for v in __done_min_cmd_duration __done_notification_urgency_level
        set -Ue $v
    end
    for v in (set -Un | string match 'sponge_*')
        set -Ue $v
    end

The `~/.terminal_history/` log directory contains your session logs. Remove
it only if you do not want to keep them.

## Fish Version Requirement

This config requires Fish 4.x or newer. Check your version:

    fish --version

Run `fish-deps` to see a status report — an outdated Fish shows ⚠ with an
upgrade message.

Upgrading Fish by distribution:

    # Arch / AUR
    pacman -S fish          # or paru -S fish

    # Ubuntu / Debian (PPA)
    sudo apt-add-repository ppa:fish-shell/release-4
    sudo apt update && sudo apt install fish

    # Fedora
    sudo dnf install fish

    # macOS
    brew install fish

For other systems or building from source, see https://fishshell.com.

## Enable or Disable Session Logging

Session logging is opt-in: it is off until you turn it on. To enable all
logging and capture (scrollback, tmux/zellij pane logs, AUR helper wrappers,
Kitty watcher):

    set -U __fish_config_op_logging on

Or toggle it interactively: run `config-settings` and flip the Logging row.

Disable it again — either an explicit falsy value or erasing the variable
returns you to the default off state:

    set -U __fish_config_op_logging off
    set -Ue __fish_config_op_logging

This takes effect immediately in all running shells — no restart needed. The
sentinel file, wrapper removal, and pipe-pane teardown happen automatically.

See [C5 — Logging and Capture](/08-components-reference/05-c5-logging-and-capture/) for the full component breakdown.

## Change or Disable the Greeting

This config suppresses the distro greeting (e.g. CachyOS fastfetch) by
default. To let the distro greeting through:

    set -U __fish_config_op_greeting off

To set a custom greeting, define fish_greeting in your local.fish:

    # in $__fish_user_dots_path/local.fish
    function fish_greeting
        echo "Hello, world!"
    end

The first-run welcome banner runs exactly once. To re-trigger it (e.g. for
testing):

    set -Ue __fish_config_first_run_complete

See [C6 — Greeting and First-Run UI](/08-components-reference/06-c6-greeting-and-first-run-ui/) for details.

## Secrets and Machine-Local Configuration

Machine-specific config goes in `$__fish_user_dots_path/local.fish` (defaults
to `~/.config/.user-dots/fish/local.fish`). Secrets go in `secrets.fish` in
the same directory.

If local.fish is not loading, verify the path:

    echo $__fish_user_dots_path
    test -f "$__fish_user_dots_path/local.fish"; and echo exists; or echo missing

Change the path via variable or TUI:

    set -U __fish_user_dots_path /new/path/to/dots/fish

Or run `config-settings`, navigate to the Paths page, and edit "Dots path".

The `user-dots` convenience symlink in the config directory tracks this path.
Disable it with:

    set -U __fish_user_dots_symlink false

See [Personalization](/11-personalization/) for the full `local.fish` / `secrets.fish`
layout.

## Tool Init Does Nothing (Return Sentinel)

Symptom: you ran a tool's setup command (e.g.
`starship init fish >> ~/.config/fish/config.fish`) and nothing changed.

Cause: `config.fish` ends with a `return` guard. Any lines appended after it
are never executed.

Fix: create a dedicated `conf.d/` file instead of appending to `config.fish`:

    # ~/.config/fish/conf.d/mytool.fish
    mytool init fish | source

All existing integrations (starship, zoxide, direnv) already have `conf.d/`
files. See [Return Sentinel](/10-installation/#return-sentinel) for background.

## Missing Dependencies

Run `fish-deps` (defaults to `fish-deps status`) to see what is installed
and what is missing. Common symptoms and their missing tools:

    Symptom                                  Missing tool
    ─────────────────────────────────────────────────────
    ls output has no icons or colors         eza (or lsd)
    cd does not remember directories         zoxide
    cat shows no syntax highlighting         bat
    fzf keybindings do nothing               fzf
    Starship prompt not appearing            starship

Install missing dependencies interactively:

    fish-deps install

Or install everything missing and update what is installed:

    fish-deps sync

See [Dependency Catalog](/06-dependency-catalog/) for the full list grouped by tier
(required, integrations, recommended).

## Vi Mode Keybindings

This config enables Vi mode by default (via C3 overrides), replacing the
standard Emacs-style bindings. If Vi mode interferes with your workflow,
override it in `local.fish` (See [Personalization](/11-personalization/)):

    # $__fish_user_dots_path/local.fish
    fish_default_key_bindings

This restores Emacs-style bindings without disabling the rest of C3
(bang-bang, autopair, starship prompt, pager settings, etc.).

To disable the entire C3 category (Vi mode and all other key/environment
overrides):

    set -U __fish_config_op_overrides off

See [C3 — Key and Environment Overrides](/08-components-reference/03-c3-key-and-environment-overrides/) for the full list of
what C3 controls.

## What's with the C1-C6 stuff?

This configuration groups its opinionated behaviors into six categories (C1–C6), allowing you to selectively disable features that conflict with your workflow. The **C**ategory numbers are used as shorthand when referencing these. Disabling all of them leaves you with a "Minimal Mode" shell that only manages basic features like `XDG` variables, and your `local.fish` overrides.

    Category   Description
    ──────────────────────────────────────────────────────────────────────────
    C1         [Command Shadows](/08-components-reference/01-c1-command-shadows/) — Wraps destructive commands (rm, cp) to be safe by default
    C2         [Startup Side-Effects](/08-components-reference/02-c2-startup-side-effects/) — Bootstraps Fisher, generates wrappers, auto-activates venvs
    C3         [Overrides](/08-components-reference/03-c3-key-and-environment-overrides/) — Overrides cd, sets Vi mode, binds <CR> to smart_enter
    C4         [Integrations](/08-components-reference/04-c4-terminal-and-tool-integration/) — Kitty/Wezterm integrations, starship hooks, fzf theme
    C5         [Logging and Capture](/08-components-reference/05-c5-logging-and-capture/) — Session logs, command duration
    C6         [Greeting & First-Run UI](/08-components-reference/06-c6-greeting-and-first-run-ui/) — Custom startup banner

Disable all opinionated features at once (Minimal Mode):

    set -U __fish_config_opinionated 0

Disable a single category:

    set -U __fish_config_op_aliases off         # C1
    set -U __fish_config_op_autoexec off        # C2
    set -U __fish_config_op_overrides off       # C3
    set -U __fish_config_op_integrations off    # C4
    set -U __fish_config_op_logging off         # C5 (already off by default)
    set -U __fish_config_op_greeting off        # C6

Keep one category active under a master disable:

    set -U __fish_config_opinionated 0
    set -U __fish_config_op_aliases 1           # only C1 stays on

Re-enable everything:

    set -Ue __fish_config_opinionated

Each category also has two to six sub-categories (e.g.
`__fish_config_op_aliases_filesystem`) that can be checked, disabled, or
reset the same way — `set -U __fish_config_op_<category>_<subcategory> off`
and `set -Ue __fish_config_op_<category>_<subcategory>` work identically to
the category-level recipes above, just one level more granular. See
[Components Reference](/08-components-reference/) for the full list.

For an interactive alternative to setting these variables by hand, run `config-settings`.

---
