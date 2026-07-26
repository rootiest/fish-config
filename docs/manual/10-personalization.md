---
title: Personalization
manTitle: 10. PERSONALIZATION
sidebar:
  order: 14
helpKeywords:
- personalization
- personalize
---

Sensitive credentials and machine-specific settings are kept out of version
control in a private directory. The path defaults to
`~/.config/.user-dots/fish/` but can be overridden:

    set -U __fish_user_dots_path /path/to/your/dots/fish

Or use the interactive TUI — run `config-settings` and navigate to the
"Dots Path" row (last row). Press Enter to type a new path, or ← / h to
reset to the default.

config.fish sources local.fish from that directory on every interactive
session. local.fish is responsible for sourcing its own secrets.fish:

    $__fish_user_dots_path/
    ├── secrets.fish   API keys, tokens, passwords, personal identifiers
    └── local.fish     Machine-specific paths, env vars, and sourcing secrets

fish_variables (auto-managed by fish) is excluded from this repo via
.gitignore. Do not commit it.

## secrets.fish

Store anything you would not commit to a public repo: API keys, auth tokens,
passwords, and personal identifiers.

    # secrets.fish
    set -gx MY_NAME "Your Name"
    set -gx MY_EMAIL "you@example.com"
    set -gx GPG_RECIPIENT "you@example.com"
    set -gx GITHUB_TOKEN ghp_yourTokenHere
    set -gx OPENAI_API_KEY sk-proj-yourKeyHere
    set -gx GITEA_TOKEN yourGiteaTokenHere
    set -gx GITEA_CHOSEN_LOGIN your.gitea.instance
    set -gx KOPIA_PASSWORD yourKopiaPassword

## local.fish

Store paths and variables specific to one machine — things that would be
wrong on any other system.

    # CDPATH — directories searched by cd
    set -gx CDPATH . /home/youruser/projects /home/youruser

    # Path to your shared .gitignore boilerplate
    set -gx GITIGNORE_BOILERPLATE ~/.config/git/gitignore_boilerplate

    # SSH shortcuts
    abbr -a sshr 'ssh you@your-server.local'
    abbr -a sshw 'ssh you@work-server.example.com'

    # Docker context shortcuts
    abbr -a dcr 'docker context use my-remote-server'
    abbr -a dcw 'docker context use work-server'

local.fish is sourced at the end of config.fish with an existence check so
the public config works cleanly on any machine without the private repo.
local.fish in turn sources secrets.fish when it exists.

---
